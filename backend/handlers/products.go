package handlers

import (
	"bstock/database"
	"bstock/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
)

type CreateProductRequest struct {
	Name        string                 `json:"name" binding:"required"`
	Description string                 `json:"description"`
	Category    string                 `json:"category"`
	ImageURL    string                 `json:"image_url"`
	VendorID    *string                `json:"vendor_id"`
	Variants    []CreateVariantRequest `json:"variants" binding:"required,min=1"`
}

type CreateVariantRequest struct {
	Attributes    map[string]string `json:"attributes"`
	SKU           string            `json:"sku" binding:"required"`
	PurchasePrice float64           `json:"purchase_price"`
	SalePrice     float64           `json:"sale_price" binding:"required,gt=0"`
	Quantity      int               `json:"quantity" binding:"gte=0"`
	MinStockLevel int               `json:"min_stock_level"`
	UnitType      string            `json:"unit_type"`
}

// CreateProduct creates a new product with variants
func CreateProduct(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var req CreateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	tx := database.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Create product
	product := models.Product{
		OrganizationID: orgID,
		Name:           req.Name,
		Description:    req.Description,
		Category:       req.Category,
		ImageURL:       req.ImageURL,
	}

	if req.VendorID != nil {
		vendorID, err := uuid.Parse(*req.VendorID)
		if err != nil {
			tx.Rollback()
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid vendor ID"})
			return
		}
		product.VendorID = &vendorID
	}

	if err := tx.Create(&product).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create product"})
		return
	}

	// Create variants
	for _, varReq := range req.Variants {
		variant := models.Variant{
			ProductID:     product.ID,
			Attributes:    varReq.Attributes,
			SKU:           varReq.SKU,
			PurchasePrice: varReq.PurchasePrice,
			SalePrice:     varReq.SalePrice,
			Quantity:      varReq.Quantity,
			MinStockLevel: varReq.MinStockLevel,
			UnitType:      varReq.UnitType,
		}

		if variant.UnitType == "" {
			variant.UnitType = "pcs"
		}

		if err := tx.Create(&variant).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to create variant: " + err.Error()})
			return
		}
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete product creation"})
		return
	}

	// Reload with variants
	database.DB.Preload("Variants").Preload("Vendor").First(&product, product.ID)
	c.JSON(http.StatusCreated, product)
}

// ListProducts returns all products for the organization
func ListProducts(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	// Optional filters
	category := c.Query("category")
	search := c.Query("search")
	lowStock := c.Query("low_stock") // "true" to filter low stock items

	query := database.DB.Where("organization_id = ?", orgID)

	if category != "" {
		query = query.Where("category = ?", category)
	}

	if search != "" {
		query = query.Where("name ILIKE ?", "%"+search+"%")
	}

	var products []models.Product
	if err := query.Preload("Variants").Preload("Vendor").Find(&products).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
		return
	}

	// Filter low stock if requested
	if lowStock == "true" {
		filtered := []models.Product{}
		for _, product := range products {
			hasLowStock := false
			for _, variant := range product.Variants {
				if variant.Quantity <= variant.MinStockLevel {
					hasLowStock = true
					break
				}
			}
			if hasLowStock {
				filtered = append(filtered, product)
			}
		}
		products = filtered
	}

	c.JSON(http.StatusOK, products)
}

// GetProduct returns a single product with all variants
func GetProduct(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	productID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	var product models.Product
	if err := database.DB.Where("id = ? AND organization_id = ?", productID, orgID).
		Preload("Variants").
		Preload("Vendor").
		First(&product).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	c.JSON(http.StatusOK, product)
}

type UpdateProductRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Category    *string `json:"category"`
	ImageURL    *string `json:"image_url"`
	VendorID    *string `json:"vendor_id"`
}

// UpdateProduct updates product details (not variants)
func UpdateProduct(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	productID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	var product models.Product
	if err := database.DB.Where("id = ? AND organization_id = ?", productID, orgID).
		First(&product).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	var req UpdateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Update fields if provided
	if req.Name != nil {
		product.Name = *req.Name
	}
	if req.Description != nil {
		product.Description = *req.Description
	}
	if req.Category != nil {
		product.Category = *req.Category
	}
	if req.ImageURL != nil {
		product.ImageURL = *req.ImageURL
	}
	if req.VendorID != nil {
		vendorID, err := uuid.Parse(*req.VendorID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid vendor ID"})
			return
		}
		product.VendorID = &vendorID
	}

	if err := database.DB.Save(&product).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product"})
		return
	}

	database.DB.Preload("Variants").Preload("Vendor").First(&product, product.ID)
	c.JSON(http.StatusOK, product)
}

// DeleteProduct deletes a product and all its variants
func DeleteProduct(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	productID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	result := database.DB.Where("id = ? AND organization_id = ?", productID, orgID).
		Delete(&models.Product{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Product deleted successfully"})
}
