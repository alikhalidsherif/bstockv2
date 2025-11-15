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

type PlanResponse struct {
	models.Plan
	IsCurrent bool `json:"is_current"`
}

// ListPlans returns all available subscription plans
func ListPlans(c *gin.Context) {
	var plans []models.Plan
	if err := database.DB.Find(&plans).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch plans"})
		return
	}

	// Get current plan
	orgID := c.MustGet("organization_id").(uuid.UUID)
	var org models.Organization
	database.DB.Preload("Subscription").First(&org, orgID)

	var currentPlanID uuid.UUID
	if org.Subscription != nil {
		currentPlanID = org.Subscription.PlanID
	}

	// Mark current plan
	response := make([]PlanResponse, len(plans))
	for i, plan := range plans {
		response[i] = PlanResponse{
			Plan:      plan,
			IsCurrent: plan.ID == currentPlanID,
		}
	}

	c.JSON(http.StatusOK, response)
}

// GetCurrentSubscription returns the organization's subscription details
func GetCurrentSubscription(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var subscription models.Subscription
	if err := database.DB.Preload("Plan").
		Where("organization_id = ?", orgID).
		First(&subscription).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No subscription found"})
		return
	}

	// Get usage stats
	var productCount, userCount int64
	database.DB.Model(&models.Product{}).Where("organization_id = ?", orgID).Count(&productCount)
	database.DB.Model(&models.OrganizationUser{}).Where("organization_id = ?", orgID).Count(&userCount)

	c.JSON(http.StatusOK, gin.H{
		"subscription": subscription,
		"usage": gin.H{
			"products": gin.H{
				"current": productCount,
				"limit":   subscription.Plan.ProductLimit,
			},
			"users": gin.H{
				"current": userCount,
				"limit":   subscription.Plan.UserLimit,
			},
		},
	})
}

type ChangePlanRequest struct {
	PlanID string `json:"plan_id" binding:"required"`
}

// ChangePlan updates the organization's subscription plan (STUBBED PAYMENT)
func ChangePlan(c *gin.Context) {
	orgID := c.MustGet("organization_id").(uuid.UUID)

	var req ChangePlanRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	planID, err := uuid.Parse(req.PlanID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid plan ID"})
		return
	}

	// Verify plan exists
	var plan models.Plan
	if err := database.DB.First(&plan, planID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Plan not found"})
		return
	}

	// Get current subscription
	var subscription models.Subscription
	if err := database.DB.Where("organization_id = ?", orgID).First(&subscription).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No subscription found"})
		return
	}

	// Check if downgrading would violate limits
	if err := validateDowngrade(orgID, &plan); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// STUBBED: In production, process payment here
	// For now, just update the plan directly

	// Update subscription
	subscription.PlanID = planID
	subscription.Status = "active"
	newPeriodEnd := time.Now().AddDate(0, 1, 0) // 1 month from now
	subscription.CurrentPeriodEnd = &newPeriodEnd

	if err := database.DB.Save(&subscription).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update subscription"})
		return
	}

	database.DB.Preload("Plan").First(&subscription, subscription.ID)
	c.JSON(http.StatusOK, gin.H{
		"message":      "Plan changed successfully",
		"subscription": subscription,
	})
}

func validateDowngrade(orgID uuid.UUID, newPlan *models.Plan) error {
	// Check product count
	if newPlan.ProductLimit != nil {
		var productCount int64
		database.DB.Model(&models.Product{}).Where("organization_id = ?", orgID).Count(&productCount)
		if productCount > int64(*newPlan.ProductLimit) {
			return fmt.Errorf("cannot downgrade: you have %d products but new plan allows only %d", productCount, *newPlan.ProductLimit)
		}
	}

	// Check user count
	if newPlan.UserLimit != nil {
		var userCount int64
		database.DB.Model(&models.OrganizationUser{}).Where("organization_id = ?", orgID).Count(&userCount)
		if userCount > int64(*newPlan.UserLimit) {
			return fmt.Errorf("cannot downgrade: you have %d users but new plan allows only %d", userCount, *newPlan.UserLimit)
		}
	}

	return nil
}

// STUBBED: Payment webhook handler
func HandlePaymentWebhook(c *gin.Context) {
	// In production, validate webhook signature
	// Process payment success/failure
	// Update subscription status accordingly

	c.JSON(http.StatusOK, gin.H{"message": "Webhook processed (stubbed)"})
}

// DevSetPlan - DEBUG ONLY: Directly set plan without payment
func DevSetPlan(c *gin.Context) {
	// Only enable in development
	if gin.Mode() != gin.DebugMode {
		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
		return
	}

	orgID := c.MustGet("organization_id").(uuid.UUID)
	planName := c.Param("plan_name")

	var plan models.Plan
	if err := database.DB.Where("name = ?", planName).First(&plan).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Plan not found"})
		return
	}

	var subscription models.Subscription
	if err := database.DB.Where("organization_id = ?", orgID).First(&subscription).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No subscription found"})
		return
	}

	subscription.PlanID = plan.ID
	subscription.Status = "active"
	database.DB.Save(&subscription)

	c.JSON(http.StatusOK, gin.H{"message": "Plan set", "plan": planName})
}
