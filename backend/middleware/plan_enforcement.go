package middleware

import (
	"bstock/database"
	"bstock/models"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GetCurrentPlan retrieves the organization's current subscription plan
func GetCurrentPlan(c *gin.Context) (*models.Plan, error) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var org models.Organization
	if err := database.DB.Preload("Subscription.Plan").First(&org, orgID).Error; err != nil {
		return nil, err
	}

	if org.Subscription == nil {
		return nil, errors.New("no active subscription")
	}

	return &org.Subscription.Plan, nil
}

// RequireAnalytics blocks access if analytics not enabled in plan
func RequireAnalytics() gin.HandlerFunc {
	return func(c *gin.Context) {
		plan, err := GetCurrentPlan(c)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve plan"})
			c.Abort()
			return
		}

		if !plan.AnalyticsEnabled {
			c.JSON(http.StatusForbidden, gin.H{
				"error":            "Analytics is not available on your current plan",
				"upgrade_required": true,
				"current_plan":     plan.Name,
			})
			c.Abort()
			return
		}

		c.Set("plan", plan)
		c.Next()
	}
}

// CheckProductLimit verifies if organization can add more products
func CheckProductLimit(c *gin.Context) {
	plan, err := GetCurrentPlan(c)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve plan"})
		c.Abort()
		return
	}

	// Unlimited products
	if plan.ProductLimit == nil {
		c.Next()
		return
	}

	orgID := c.MustGet("organization_id").(uuid.UUID)

	var count int64
	if err := database.DB.Model(&models.Product{}).
		Where("organization_id = ?", orgID).
		Count(&count).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count products"})
		c.Abort()
		return
	}

	if count >= int64(*plan.ProductLimit) {
		c.JSON(http.StatusForbidden, gin.H{
			"error":            "Product limit reached for your current plan",
			"limit":            *plan.ProductLimit,
			"current_count":    count,
			"upgrade_required": true,
		})
		c.Abort()
		return
	}

	c.Next()
}

// CheckUserLimit verifies if organization can add more users
func CheckUserLimit(c *gin.Context) {
	plan, err := GetCurrentPlan(c)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve plan"})
		c.Abort()
		return
	}

	// Unlimited users
	if plan.UserLimit == nil {
		c.Next()
		return
	}

	orgID := c.MustGet("organization_id").(uuid.UUID)

	var count int64
	if err := database.DB.Model(&models.OrganizationUser{}).
		Where("organization_id = ?", orgID).
		Count(&count).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count users"})
		c.Abort()
		return
	}

	if count >= int64(*plan.UserLimit) {
		c.JSON(http.StatusForbidden, gin.H{
			"error":            "User limit reached for your current plan",
			"limit":            *plan.UserLimit,
			"current_count":    count,
			"upgrade_required": true,
		})
		c.Abort()
		return
	}

	c.Next()
}
