package handlers

import (
	"bstock/database"
	"bstock/models"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateSaleRequest struct {
	PaymentMethod string            `json:"payment_method" binding:"required"`
	Items         []SaleItemRequest `json:"items" binding:"required,min=1"`
}

type SaleItemRequest struct {
	VariantID string `json:"variant_id" binding:"required"`
	Quantity  int    `json:"quantity" binding:"required,gt=0"`
}

// ProcessSale creates a new sale and decrements inventory atomically
func ProcessSale(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	userID := c.MustGet("user_id").(uuid.UUID)

	var req CreateSaleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Start atomic transaction
	tx := database.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	var totalAmount float64
	var totalProfit float64
	var saleItems []models.SaleItem

	// Process each item
	for _, itemReq := range req.Items {
		variantID, err := uuid.Parse(itemReq.VariantID)
		if err != nil {
			tx.Rollback()
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid variant ID: " + itemReq.VariantID})
			return
		}

		// Lock variant row for update
		var variant models.Variant
		if err := tx.Set("gorm:query_option", "FOR UPDATE").
			Joins("JOIN products ON products.id = variants.product_id").
			Where("variants.id = ? AND products.organization_id = ?", variantID, orgID).
			First(&variant).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusNotFound, gin.H{"error": "Variant not found: " + itemReq.VariantID})
			return
		}

		// Check stock availability
		if variant.Quantity < itemReq.Quantity {
			tx.Rollback()
			c.JSON(http.StatusBadRequest, gin.H{
				"error":     "Insufficient stock",
				"variant_id": variantID.String(),
				"available":  variant.Quantity,
				"requested":  itemReq.Quantity,
			})
			return
		}

		// Calculate amounts
		itemTotal := variant.SalePrice * float64(itemReq.Quantity)
		itemCost := variant.PurchasePrice * float64(itemReq.Quantity)
		itemProfit := itemTotal - itemCost

		totalAmount += itemTotal
		totalProfit += itemProfit

		// Decrement stock
		variant.Quantity -= itemReq.Quantity
		if err := tx.Save(&variant).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update stock"})
			return
		}

		// Prepare sale item
		saleItems = append(saleItems, models.SaleItem{
			VariantID:           variantID,
			Quantity:            itemReq.Quantity,
			PriceAtSale:         variant.SalePrice,
			PurchasePriceAtSale: variant.PurchasePrice,
		})
	}

	// Create sale record
	sale := models.Sale{
		OrganizationID: orgID,
		UserID:         userID,
		TotalAmount:    totalAmount,
		TotalProfit:    totalProfit,
		PaymentMethod:  req.PaymentMethod,
		IsSynced:       true,
	}

	if err := tx.Create(&sale).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create sale"})
		return
	}

	// Create sale items
	for i := range saleItems {
		saleItems[i].SaleID = sale.ID
		if err := tx.Create(&saleItems[i]).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create sale items"})
			return
		}
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete sale"})
		return
	}

	// Reload with associations
	database.DB.Preload("Items.Variant.Product").Preload("User").First(&sale, sale.ID)
	c.JSON(http.StatusCreated, sale)
}

// ListSales returns paginated sales history
func ListSales(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	// Pagination
	page := 1
	limit := 50
	if p := c.Query("page"); p != "" {
		fmt.Sscanf(p, "%d", &page)
	}
	if l := c.Query("limit"); l != "" {
		fmt.Sscanf(l, "%d", &limit)
	}
	offset := (page - 1) * limit

	// Date filters
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	query := database.DB.Where("organization_id = ?", orgID)

	if startDate != "" {
		start, _ := time.Parse("2006-01-02", startDate)
		query = query.Where("created_at >= ?", start)
	}
	if endDate != "" {
		end, _ := time.Parse("2006-01-02", endDate)
		query = query.Where("created_at <= ?", end.Add(24*time.Hour))
	}

	var sales []models.Sale
	var total int64

	query.Model(&models.Sale{}).Count(&total)
	if err := query.
		Preload("Items.Variant.Product").
		Preload("User").
		Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&sales).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sales"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sales":       sales,
		"total":       total,
		"page":        page,
		"limit":       limit,
		"total_pages": (total + int64(limit) - 1) / int64(limit),
	})
}

// GetSale returns a single sale with details
func GetSale(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	saleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid sale ID"})
		return
	}

	var sale models.Sale
	if err := database.DB.Where("id = ? AND organization_id = ?", saleID, orgID).
		Preload("Items.Variant.Product").
		Preload("User").
		First(&sale).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Sale not found"})
		return
	}

	c.JSON(http.StatusOK, sale)
}

// UploadPaymentProof handles payment proof image upload
func UploadPaymentProof(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	saleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid sale ID"})
		return
	}

	var sale models.Sale
	if err := database.DB.Where("id = ? AND organization_id = ?", saleID, orgID).
		First(&sale).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Sale not found"})
		return
	}

	file, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No image file provided"})
		return
	}

	// Save file locally (in production, use S3 or similar)
	filename := fmt.Sprintf("payment_proof_%s_%s", saleID.String(), file.Filename)
	filepath := fmt.Sprintf("./uploads/%s", filename)

	if err := c.SaveUploadedFile(file, filepath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save image"})
		return
	}

	// Update sale record
	sale.PaymentProofURL = filepath
	if err := database.DB.Save(&sale).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update sale"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Payment proof uploaded",
		"url":     filepath,
	})
}
