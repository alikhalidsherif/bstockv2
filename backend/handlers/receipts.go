package handlers

import (
	"bstock/database"
	"bstock/models"
	"bstock/services"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func GetReceipt(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	saleID, err := uuid.Parse(c.Param("sale_id"))
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

	var org models.Organization
	database.DB.First(&org, orgID)

	receiptService := services.NewReceiptService()
	receipt, err := receiptService.GenerateReceipt(&sale, &org)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate receipt"})
		return
	}

	c.Header("Content-Type", "text/plain")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=receipt_%s.txt", saleID.String()[:8]))
	c.Data(http.StatusOK, "text/plain", receipt)
}
