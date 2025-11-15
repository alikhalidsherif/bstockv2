package handlers

import (
	"bstock/database"
	"bstock/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
)

type CreateVendorRequest struct {
	Name        string `json:"name" binding:"required"`
	ContactInfo string `json:"contact_info"`
}

func ListVendors(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var vendors []models.Vendor
	if err := database.DB.Where("organization_id = ?", orgID).Find(&vendors).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch vendors"})
		return
	}

	c.JSON(http.StatusOK, vendors)
}

func CreateVendor(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var req CreateVendorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	vendor := models.Vendor{
		OrganizationID: orgID,
		Name:           req.Name,
		ContactInfo:    req.ContactInfo,
	}

	if err := database.DB.Create(&vendor).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create vendor"})
		return
	}

	c.JSON(http.StatusCreated, vendor)
}

func DeleteVendor(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	vendorID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid vendor ID"})
		return
	}

	result := database.DB.Where("id = ? AND organization_id = ?", vendorID, orgID).
		Delete(&models.Vendor{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete vendor"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Vendor not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Vendor deleted successfully"})
}
