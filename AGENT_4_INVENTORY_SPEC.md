# Agent 4: Backend - Inventory Management API

## Timeline: Day 1-2 (Start after Agent 2, parallel with Agents 3, 5, 6)
## Dependencies: Agents 2 (auth), 3 (plan enforcement)
## Priority: CRITICAL - Required for Agent 8 (Flutter UI) and Agent 5 (Sales)

---

## Mission
Build complete inventory management system with products, variants, vendors, and stock control.

---

## Deliverables Checklist

### 1. Product Model
**File**: `backend/models/product.go`

```go
package models

import "github.com/google/uuid"

type Product struct {
    BaseModel
    OrganizationID uuid.UUID `gorm:"not null;index" json:"organization_id"`
    Name           string    `gorm:"not null" json:"name"`
    Description    string    `json:"description"`
    Category       string    `json:"category"`
    ImageURL       string    `json:"image_url"`
    VendorID       *uuid.UUID `json:"vendor_id,omitempty"`
    Vendor         *Vendor   `gorm:"foreignKey:VendorID" json:"vendor,omitempty"`
    Variants       []Variant `gorm:"foreignKey:ProductID;constraint:OnDelete:CASCADE" json:"variants,omitempty"`
}

type Variant struct {
    BaseModel
    ProductID      uuid.UUID              `gorm:"not null;index" json:"product_id"`
    Attributes     map[string]string      `gorm:"type:jsonb;default:'{}'" json:"attributes"` // e.g., {"Size": "L", "Color": "Red"}
    SKU            string                 `gorm:"not null" json:"sku"`
    PurchasePrice  float64                `gorm:"not null;default:0" json:"purchase_price"`
    SalePrice      float64                `gorm:"not null" json:"sale_price"`
    Quantity       int                    `gorm:"not null;default:0" json:"quantity"`
    MinStockLevel  int                    `gorm:"default:0" json:"min_stock_level"`
    UnitType       string                 `gorm:"default:'pcs'" json:"unit_type"` // pcs, kg, L, etc.
    Product        Product                `gorm:"foreignKey:ProductID" json:"product,omitempty"`
}

type Vendor struct {
    BaseModel
    OrganizationID uuid.UUID `gorm:"not null;index" json:"organization_id"`
    Name           string    `gorm:"not null" json:"name"`
    ContactInfo    string    `json:"contact_info"`
}
```

### 2. Product Handlers
**File**: `backend/handlers/products.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
)

type CreateProductRequest struct {
    Name        string              `json:"name" binding:"required"`
    Description string              `json:"description"`
    Category    string              `json:"category"`
    ImageURL    string              `json:"image_url"`
    VendorID    *string             `json:"vendor_id"`
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
    tx.Preload("Variants").Preload("Vendor").First(&product, product.ID)
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
```

### 3. Variant Handlers
**File**: `backend/handlers/variants.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
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
```

### 4. Vendor Handlers
**File**: `backend/handlers/vendors.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
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
```

### 5. Update Routes
**File**: `backend/routes/routes.go` (ADD)

```go
// Add to protected routes

// Products
products := protected.Group("/products")
{
    products.GET("", handlers.ListProducts)
    products.POST("", middleware.CheckProductLimit, handlers.CreateProduct)
    products.GET("/:id", handlers.GetProduct)
    products.PUT("/:id", handlers.UpdateProduct)
    products.DELETE("/:id", middleware.RequireRole("owner"), handlers.DeleteProduct)
}

// Variants
variants := protected.Group("/variants")
{
    variants.PUT("/:id", handlers.UpdateVariant)
    variants.POST("/:id/adjust-stock", handlers.AdjustStock)
    variants.GET("/low-stock", handlers.GetLowStockAlerts)
}

// Vendors
vendors := protected.Group("/vendors")
{
    vendors.GET("", handlers.ListVendors)
    vendors.POST("", handlers.CreateVendor)
    vendors.DELETE("/:id", handlers.DeleteVendor)
}
```

---

## Testing Checklist

```bash
# Create vendor
curl -X POST http://localhost:8080/api/v1/vendors \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name": "Supplier ABC", "contact_info": "+251911234567"}'

# Create product with variants
curl -X POST http://localhost:8080/api/v1/products \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "T-Shirt",
    "category": "Clothing",
    "description": "Cotton t-shirt",
    "variants": [
      {"sku": "TSHIRT-S", "sale_price": 299.99, "quantity": 10, "attributes": {"Size": "Small"}},
      {"sku": "TSHIRT-M", "sale_price": 299.99, "quantity": 15, "attributes": {"Size": "Medium"}},
      {"sku": "TSHIRT-L", "sale_price": 299.99, "quantity": 8, "attributes": {"Size": "Large"}}
    ]
  }'

# List products
curl -X GET http://localhost:8080/api/v1/products \
  -H "Authorization: Bearer <TOKEN>"

# Update variant stock
curl -X PUT http://localhost:8080/api/v1/variants/<VARIANT_ID> \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"quantity": 20}'

# Adjust stock
curl -X POST http://localhost:8080/api/v1/variants/<VARIANT_ID>/adjust-stock \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"adjustment": 5, "reason": "New delivery"}'

# Get low stock alerts
curl -X GET http://localhost:8080/api/v1/variants/low-stock \
  -H "Authorization: Bearer <TOKEN>"
```

- [ ] Create product with multiple variants
- [ ] List products with filters
- [ ] Update product details
- [ ] Delete product (cascades to variants)
- [ ] Update variant price and stock
- [ ] Stock adjustment works
- [ ] Low stock alerts accurate
- [ ] Vendor CRUD operations
- [ ] Product limit enforced (free plan = 15)

---

## Success Criteria

1. ✅ Complete product/variant CRUD
2. ✅ Stock management working
3. ✅ Low stock alerts functional
4. ✅ Vendor management complete
5. ✅ Multi-tenancy enforced
6. ✅ Plan limits enforced

**Estimated Completion: 8-10 hours**
