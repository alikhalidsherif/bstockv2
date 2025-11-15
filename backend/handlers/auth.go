package handlers

import (
	"bstock/database"
	"bstock/models"
	"bstock/utils"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"net/http"
)

type RegisterRequest struct {
	OrganizationName string `json:"organization_name" binding:"required"`
	PhoneNumber      string `json:"phone_number" binding:"required"`
	Password         string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	OrganizationName string `json:"organization_name" binding:"required"`
	PhoneNumber      string `json:"phone_number" binding:"required"`
	Password         string `json:"password" binding:"required"`
}

type AuthResponse struct {
	Token        string              `json:"token"`
	User         models.User         `json:"user"`
	Organization models.Organization `json:"organization"`
	Role         string              `json:"role"`
}

func Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Start transaction
	tx := database.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Check if organization already exists
	var existingOrg models.Organization
	if err := tx.Where("name = ?", req.OrganizationName).First(&existingOrg).Error; err == nil {
		tx.Rollback()
		c.JSON(http.StatusConflict, gin.H{"error": "Organization name already taken"})
		return
	}

	// Create user
	user := models.User{
		PhoneNumber: req.PhoneNumber,
	}
	if err := user.SetPassword(req.Password); err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	if err := tx.Create(&user).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusConflict, gin.H{"error": "Phone number already registered"})
		return
	}

	// Create organization
	org := models.Organization{
		Name:    req.OrganizationName,
		OwnerID: user.ID,
	}
	if err := tx.Create(&org).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create organization"})
		return
	}

	// Create organization_user relationship
	orgUser := models.OrganizationUser{
		UserID:         user.ID,
		OrganizationID: org.ID,
		Role:           "owner",
	}
	if err := tx.Create(&orgUser).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create organization membership"})
		return
	}

	// Get free plan and create subscription
	var freePlan models.Plan
	if err := tx.Where("name = ?", "free").First(&freePlan).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to find free plan"})
		return
	}

	subscription := models.Subscription{
		OrganizationID: org.ID,
		PlanID:         freePlan.ID,
		Status:         "active",
	}
	if err := tx.Create(&subscription).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create subscription"})
		return
	}

	// Update organization with subscription
	org.SubscriptionID = &subscription.ID
	if err := tx.Save(&org).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to link subscription"})
		return
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete registration"})
		return
	}

	// Generate JWT
	token, err := utils.GenerateJWT(user.ID, org.ID, "owner")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusCreated, AuthResponse{
		Token:        token,
		User:         user,
		Organization: org,
		Role:         "owner",
	})
}

func Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Find organization
	var org models.Organization
	if err := database.DB.Where("name = ?", req.OrganizationName).First(&org).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Find user
	var user models.User
	if err := database.DB.Where("phone_number = ?", req.PhoneNumber).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Check password
	if !user.CheckPassword(req.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Find organization membership
	var orgUser models.OrganizationUser
	if err := database.DB.Where("user_id = ? AND organization_id = ?", user.ID, org.ID).First(&orgUser).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not member of this organization"})
		return
	}

	// Generate JWT
	token, err := utils.GenerateJWT(user.ID, org.ID, orgUser.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, AuthResponse{
		Token:        token,
		User:         user,
		Organization: org,
		Role:         orgUser.Role,
	})
}
