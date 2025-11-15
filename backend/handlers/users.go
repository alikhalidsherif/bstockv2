package handlers

import (
	"bstock/database"
	"bstock/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
)

type InviteUserRequest struct {
	PhoneNumber string `json:"phone_number" binding:"required"`
	Password    string `json:"password" binding:"required,min=6"`
	Role        string `json:"role" binding:"required,oneof=owner cashier"`
}

func ListUsers(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var orgUsers []models.OrganizationUser
	if err := database.DB.Where("organization_id = ?", orgID).
		Preload("User").
		Find(&orgUsers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}

	c.JSON(http.StatusOK, orgUsers)
}

func InviteUser(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var req InviteUserRequest
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

	// Check if user exists, create if not
	var user models.User
	err := tx.Where("phone_number = ?", req.PhoneNumber).First(&user).Error
	if err != nil {
		// Create new user
		user = models.User{
			PhoneNumber: req.PhoneNumber,
		}
		if err := user.SetPassword(req.Password); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}
		if err := tx.Create(&user).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}
	}

	// Check if already member
	var existing models.OrganizationUser
	if err := tx.Where("user_id = ? AND organization_id = ?", user.ID, orgID).First(&existing).Error; err == nil {
		tx.Rollback()
		c.JSON(http.StatusConflict, gin.H{"error": "User already member of organization"})
		return
	}

	// Create membership
	orgUser := models.OrganizationUser{
		UserID:         user.ID,
		OrganizationID: orgID,
		Role:           req.Role,
	}
	if err := tx.Create(&orgUser).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add user to organization"})
		return
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete invitation"})
		return
	}

	tx.Preload("User").First(&orgUser, orgUser.ID)
	c.JSON(http.StatusCreated, orgUser)
}

func RemoveUser(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)
	userIDParam := c.Param("id")

	userID, err := uuid.Parse(userIDParam)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Cannot remove owner
	var org models.Organization
	if err := database.DB.First(&org, orgID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Organization not found"})
		return
	}

	if org.OwnerID == userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Cannot remove organization owner"})
		return
	}

	// Delete membership
	result := database.DB.Where("user_id = ? AND organization_id = ?", userID, orgID).
		Delete(&models.OrganizationUser{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove user"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found in organization"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User removed successfully"})
}
