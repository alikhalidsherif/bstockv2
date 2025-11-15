package handlers

import (
	"bstock/database"
	"bstock/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
)

type UpdateVariantRequest struct {
	PurchasePrice *float64 `json:"purchase_price"`
	SalePrice     *float64 `json:"sale_price"`
	Quantity      *int     `json:"quantity"`
	MinStockLevel *int     `json:"min_stock_level"`
	SKU           *string  `json:"sku"`
	UnitType      *string  `json:"unit_type"`
}

type StockAdjustmentRequest struct {
	Adjustment int    `json:"adjustment" binding:"required"` // Can be positive or negative
	Reason     string `json:"reason"`
}

// UpdateVariant updates a variant's details
func UpdateVariant(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	variantID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid variant ID"})
		return
	}

	// Verify variant belongs to organization
	var variant models.Variant
	if err := database.DB.Joins("JOIN products ON products.id = variants.product_id").
		Where("variants.id = ? AND products.organization_id = ?", variantID, orgID).
		First(&variant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Variant not found"})
		return
	}

	var req UpdateVariantRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.PurchasePrice != nil {
		variant.PurchasePrice = *req.PurchasePrice
	}
	if req.SalePrice != nil {
		variant.SalePrice = *req.SalePrice
	}
	if req.Quantity != nil {
		variant.Quantity = *req.Quantity
	}
	if req.MinStockLevel != nil {
		variant.MinStockLevel = *req.MinStockLevel
	}
	if req.SKU != nil {
		variant.SKU = *req.SKU
	}
	if req.UnitType != nil {
		variant.UnitType = *req.UnitType
	}

	if err := database.DB.Save(&variant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update variant"})
		return
	}

	c.JSON(http.StatusOK, variant)
}

// AdjustStock adjusts the stock quantity of a variant
func AdjustStock(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	variantID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid variant ID"})
		return
	}

	var variant models.Variant
	if err := database.DB.Joins("JOIN products ON products.id = variants.product_id").
		Where("variants.id = ? AND products.organization_id = ?", variantID, orgID).
		First(&variant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Variant not found"})
		return
	}

	var req StockAdjustmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	newQuantity := variant.Quantity + req.Adjustment
	if newQuantity < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Stock cannot be negative"})
		return
	}

	variant.Quantity = newQuantity

	if err := database.DB.Save(&variant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to adjust stock"})
		return
	}

	c.JSON(http.StatusOK, variant)
}

// GetLowStockAlerts returns all variants below minimum stock level
func GetLowStockAlerts(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var variants []models.Variant
	if err := database.DB.
		Joins("JOIN products ON products.id = variants.product_id").
		Where("products.organization_id = ? AND variants.quantity <= variants.min_stock_level", orgID).
		Preload("Product").
		Find(&variants).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch low stock items"})
		return
	}

	c.JSON(http.StatusOK, variants)
}
