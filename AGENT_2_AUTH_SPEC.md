# Agent 2: Backend - Authentication & User Management

## Timeline: Day 1 (Start after Agent 1 completes schema - ~2 hours delay, then 8 hours work)
## Dependencies: Agent 1 (database schema)
## Priority: CRITICAL - Blocks Agents 3-6, 7-10

---

## Mission
Build complete JWT-based authentication system with multi-tenant support, user management, and role-based authorization.

---

## Deliverables Checklist

### 1. User Model
**File**: `backend/models/user.go`

```go
package models

import (
    "github.com/google/uuid"
    "golang.org/x/crypto/bcrypt"
)

type User struct {
    BaseModel
    PhoneNumber  string             `gorm:"uniqueIndex;not null" json:"phone_number"`
    PasswordHash string             `gorm:"not null" json:"-"`
    Organizations []Organization    `gorm:"many2many:organization_users;" json:"organizations,omitempty"`
}

type OrganizationUser struct {
    BaseModel
    UserID         uuid.UUID `gorm:"not null" json:"user_id"`
    OrganizationID uuid.UUID `gorm:"not null" json:"organization_id"`
    Role           string    `gorm:"not null;check:role IN ('owner', 'cashier')" json:"role"`
    User           User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
    Organization   Organization `gorm:"foreignKey:OrganizationID" json:"organization,omitempty"`
}

func (u *User) SetPassword(password string) error {
    hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return err
    }
    u.PasswordHash = string(hash)
    return nil
}

func (u *User) CheckPassword(password string) bool {
    err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password))
    return err == nil
}
```

### 2. Organization Model
**File**: `backend/models/organization.go`

```go
package models

import "github.com/google/uuid"

type Organization struct {
    BaseModel
    Name           string         `gorm:"uniqueIndex;not null" json:"name"`
    OwnerID        uuid.UUID      `gorm:"not null" json:"owner_id"`
    SubscriptionID *uuid.UUID     `json:"subscription_id,omitempty"`
    Owner          User           `gorm:"foreignKey:OwnerID" json:"owner,omitempty"`
    Subscription   *Subscription  `gorm:"foreignKey:SubscriptionID" json:"subscription,omitempty"`
    Users          []User         `gorm:"many2many:organization_users;" json:"users,omitempty"`
}
```

### 3. JWT Utilities
**File**: `backend/utils/jwt.go`

```go
package utils

import (
    "errors"
    "os"
    "time"
    "github.com/golang-jwt/jwt/v5"
    "github.com/google/uuid"
)

type Claims struct {
    UserID         uuid.UUID `json:"user_id"`
    OrganizationID uuid.UUID `json:"organization_id"`
    Role           string    `json:"role"`
    jwt.RegisteredClaims
}

func GenerateJWT(userID, organizationID uuid.UUID, role string) (string, error) {
    claims := &Claims{
        UserID:         userID,
        OrganizationID: organizationID,
        Role:           role,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(getJWTSecret()))
}

func ValidateJWT(tokenString string) (*Claims, error) {
    claims := &Claims{}
    token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
        return []byte(getJWTSecret()), nil
    })

    if err != nil {
        return nil, err
    }

    if !token.Valid {
        return nil, errors.New("invalid token")
    }

    return claims, nil
}

func getJWTSecret() string {
    secret := os.Getenv("JWT_SECRET")
    if secret == "" {
        secret = "default-secret-change-in-production"
    }
    return secret
}
```

### 4. Auth Middleware
**File**: `backend/middleware/auth.go`

```go
package middleware

import (
    "bstock/utils"
    "net/http"
    "strings"
    "github.com/gin-gonic/gin"
)

func AuthRequired() gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }

        tokenString := strings.TrimPrefix(authHeader, "Bearer ")
        claims, err := utils.ValidateJWT(tokenString)
        if err != nil {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }

        // Set claims in context for use in handlers
        c.Set("user_id", claims.UserID)
        c.Set("organization_id", claims.OrganizationID)
        c.Set("role", claims.Role)
        c.Next()
    }
}

func RequireRole(allowedRoles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        role, exists := c.Get("role")
        if !exists {
            c.JSON(http.StatusForbidden, gin.H{"error": "Role not found in context"})
            c.Abort()
            return
        }

        userRole := role.(string)
        for _, allowedRole := range allowedRoles {
            if userRole == allowedRole {
                c.Next()
                return
            }
        }

        c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})
        c.Abort()
    }
}
```

### 5. Auth Handlers
**File**: `backend/handlers/auth.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "bstock/utils"
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "gorm.io/gorm"
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
```

### 6. User Management Handlers
**File**: `backend/handlers/users.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
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
```

### 7. Router Setup
**File**: `backend/routes/routes.go`

```go
package routes

import (
    "bstock/handlers"
    "bstock/middleware"
    "github.com/gin-gonic/gin"
)

func SetupRoutes(r *gin.Engine) {
    api := r.Group("/api/v1")
    {
        // Public routes
        auth := api.Group("/auth")
        {
            auth.POST("/register", handlers.Register)
            auth.POST("/login", handlers.Login)
        }

        // Protected routes
        protected := api.Group("")
        protected.Use(middleware.AuthRequired())
        {
            // User management (Owner only)
            users := protected.Group("/users")
            users.Use(middleware.RequireRole("owner"))
            {
                users.GET("", handlers.ListUsers)
                users.POST("/invite", handlers.InviteUser)
                users.DELETE("/:id", handlers.RemoveUser)
            }
        }
    }
}
```

### 8. Update Main Server
**File**: `backend/cmd/server/main.go`

```go
package main

import (
    "bstock/database"
    "bstock/models"
    "bstock/routes"
    "log"
    "github.com/gin-gonic/gin"
)

func main() {
    // Connect to database
    if err := database.Connect(); err != nil {
        log.Fatal("Failed to connect to database:", err)
    }

    // Auto-migrate models
    if err := database.DB.AutoMigrate(
        &models.User{},
        &models.Organization{},
        &models.OrganizationUser{},
        &models.Plan{},
        &models.Subscription{},
    ); err != nil {
        log.Fatal("Failed to migrate database:", err)
    }

    // Seed database
    if err := database.SeedDatabase(database.DB); err != nil {
        log.Fatal("Failed to seed database:", err)
    }

    // Setup Gin router
    r := gin.Default()
    r.Use(gin.Recovery())

    // Setup routes
    routes.SetupRoutes(r)

    r.GET("/health", func(c *gin.Context) {
        c.JSON(200, gin.H{"status": "ok"})
    })

    // Start server
    if err := r.Run(":8080"); err != nil {
        log.Fatal("Failed to start server:", err)
    }
}
```

### 9. Subscription Model (Placeholder for Agent 3)
**File**: `backend/models/subscription.go`

```go
package models

import "github.com/google/uuid"

type Plan struct {
    BaseModel
    Name             string  `gorm:"uniqueIndex;not null" json:"name"`
    PriceMonthly     float64 `json:"price_monthly"`
    ProductLimit     *int    `json:"product_limit"`
    UserLimit        *int    `json:"user_limit"`
    LocationLimit    *int    `json:"location_limit"`
    AnalyticsEnabled bool    `gorm:"not null;default:false" json:"analytics_enabled"`
}

type Subscription struct {
    BaseModel
    OrganizationID    uuid.UUID    `gorm:"uniqueIndex;not null" json:"organization_id"`
    PlanID            uuid.UUID    `gorm:"not null" json:"plan_id"`
    Status            string       `gorm:"not null;check:status IN ('active', 'trial', 'canceled')" json:"status"`
    CurrentPeriodEnd  *time.Time   `json:"current_period_end,omitempty"`
    Plan              Plan         `gorm:"foreignKey:PlanID" json:"plan,omitempty"`
}
```

---

## Testing Checklist

### API Tests
```bash
# Register new organization
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "password123"
  }'

# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "password123"
  }'

# List users (with token)
curl -X GET http://localhost:8080/api/v1/users \
  -H "Authorization: Bearer <TOKEN>"

# Invite user
curl -X POST http://localhost:8080/api/v1/users/invite \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+251911234568",
    "password": "password123",
    "role": "cashier"
  }'
```

- [ ] Registration creates user, org, and subscription
- [ ] Login returns valid JWT
- [ ] JWT contains correct claims
- [ ] Protected routes reject unauthenticated requests
- [ ] Owner-only routes reject cashier tokens
- [ ] User invitation works
- [ ] User removal works (except owner)

---

## Success Criteria

1. ✅ Complete authentication flow working
2. ✅ JWT generation and validation
3. ✅ Role-based authorization
4. ✅ User management endpoints
5. ✅ Multi-tenancy foundation established
6. ✅ All tests passing

**Estimated Completion: 8 hours**
