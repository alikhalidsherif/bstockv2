# Agent 3: Backend - Subscription & Plan Enforcement

## Timeline: Day 1-2 (Start after Agent 2, parallel with Agents 4-6)
## Dependencies: Agent 2 (auth system)
## Priority: HIGH - Required for feature gating

---

## Mission
Implement subscription plan enforcement, resource limits, and feature gates to enable the freemium business model.

---

## Deliverables Checklist

### 1. Plan Enforcement Middleware
**File**: `backend/middleware/plan_enforcement.go`

```go
package middleware

import (
    "bstock/database"
    "bstock/models"
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
                "error": "Analytics is not available on your current plan",
                "upgrade_required": true,
                "current_plan": plan.Name,
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
            "error": "Product limit reached for your current plan",
            "limit": *plan.ProductLimit,
            "current_count": count,
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
            "error": "User limit reached for your current plan",
            "limit": *plan.UserLimit,
            "current_count": count,
            "upgrade_required": true,
        })
        c.Abort()
        return
    }

    c.Next()
}
```

### 2. Subscription Handlers
**File**: `backend/handlers/subscriptions.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
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
```

### 3. Update Routes
**File**: `backend/routes/routes.go` (UPDATE)

```go
// Add to SetupRoutes function

protected := api.Group("")
protected.Use(middleware.AuthRequired())
{
    // Subscriptions
    subscriptions := protected.Group("/subscriptions")
    {
        subscriptions.GET("/plans", handlers.ListPlans)
        subscriptions.GET("/current", handlers.GetCurrentSubscription)
        subscriptions.POST("/change-plan", middleware.RequireRole("owner"), handlers.ChangePlan)

        // Debug endpoint
        subscriptions.POST("/dev/set-plan/:plan_name", handlers.DevSetPlan)
    }

    // Webhooks (public, but validated in handler)
    api.POST("/webhooks/payment", handlers.HandlePaymentWebhook)
}
```

### 4. Update User Management Routes
**File**: `backend/routes/routes.go` (UPDATE)

```go
// Update users routes to include limit checking
users := protected.Group("/users")
users.Use(middleware.RequireRole("owner"))
{
    users.GET("", handlers.ListUsers)
    users.POST("/invite", middleware.CheckUserLimit, handlers.InviteUser)
    users.DELETE("/:id", handlers.RemoveUser)
}
```

### 5. Services Package
**File**: `backend/services/subscription_service.go`

```go
package services

import (
    "bstock/database"
    "bstock/models"
    "github.com/google/uuid"
)

type SubscriptionService struct{}

func NewSubscriptionService() *SubscriptionService {
    return &SubscriptionService{}
}

// GetOrganizationPlan retrieves the plan for an organization
func (s *SubscriptionService) GetOrganizationPlan(orgID uuid.UUID) (*models.Plan, error) {
    var org models.Organization
    if err := database.DB.Preload("Subscription.Plan").First(&org, orgID).Error; err != nil {
        return nil, err
    }

    if org.Subscription == nil {
        return nil, errors.New("no subscription found")
    }

    return &org.Subscription.Plan, nil
}

// CanAddProduct checks if organization can add more products
func (s *SubscriptionService) CanAddProduct(orgID uuid.UUID) (bool, error) {
    plan, err := s.GetOrganizationPlan(orgID)
    if err != nil {
        return false, err
    }

    if plan.ProductLimit == nil {
        return true, nil // Unlimited
    }

    var count int64
    if err := database.DB.Model(&models.Product{}).
        Where("organization_id = ?", orgID).
        Count(&count).Error; err != nil {
        return false, err
    }

    return count < int64(*plan.ProductLimit), nil
}

// CanAddUser checks if organization can add more users
func (s *SubscriptionService) CanAddUser(orgID uuid.UUID) (bool, error) {
    plan, err := s.GetOrganizationPlan(orgID)
    if err != nil {
        return false, err
    }

    if plan.UserLimit == nil {
        return true, nil // Unlimited
    }

    var count int64
    if err := database.DB.Model(&models.OrganizationUser{}).
        Where("organization_id = ?", orgID).
        Count(&count).Error; err != nil {
        return false, err
    }

    return count < int64(*plan.UserLimit), nil
}

// HasAnalyticsAccess checks if organization can access analytics
func (s *SubscriptionService) HasAnalyticsAccess(orgID uuid.UUID) (bool, error) {
    plan, err := s.GetOrganizationPlan(orgID)
    if err != nil {
        return false, err
    }

    return plan.AnalyticsEnabled, nil
}
```

---

## Testing Checklist

```bash
# List available plans
curl -X GET http://localhost:8080/api/v1/subscriptions/plans \
  -H "Authorization: Bearer <TOKEN>"

# Get current subscription
curl -X GET http://localhost:8080/api/v1/subscriptions/current \
  -H "Authorization: Bearer <TOKEN>"

# Change plan (owner only)
curl -X POST http://localhost:8080/api/v1/subscriptions/change-plan \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"plan_id": "<PLAN_UUID>"}'

# Dev: Set to pro plan
curl -X POST http://localhost:8080/api/v1/subscriptions/dev/set-plan/pro \
  -H "Authorization: Bearer <TOKEN>"

# Test product limit enforcement
# 1. Set to free plan (15 product limit)
# 2. Try to add 16th product - should fail
# 3. Upgrade to growth plan
# 4. Should now be able to add products

# Test analytics gate
# 1. Set to free plan
# 2. Try to access analytics endpoint - should fail
# 3. Upgrade to growth plan
# 4. Should now access analytics
```

- [ ] Plans list correctly
- [ ] Current subscription shows with usage stats
- [ ] Plan changes work
- [ ] Product limit enforced
- [ ] User limit enforced
- [ ] Analytics access gated
- [ ] Downgrade validation works
- [ ] Dev endpoint works in debug mode

---

## Integration Points

- **Agent 2**: Uses auth middleware
- **Agent 4**: Product creation blocked by limits
- **Agent 6**: Analytics endpoints require plan check
- **Agent 7**: Frontend displays plan limits

---

## Success Criteria

1. ✅ All three plans properly enforced
2. ✅ Resource limits prevent overuse
3. ✅ Feature gates block unauthorized access
4. ✅ Upgrade/downgrade logic works
5. ✅ Usage tracking accurate
6. ✅ Dev tools for testing

**Estimated Completion: 6-8 hours**
