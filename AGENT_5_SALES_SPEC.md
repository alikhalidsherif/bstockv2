# Agent 5: Backend - POS & Sales API

## Timeline: Day 2 (Start after Agent 4, parallel with Agent 6)
## Dependencies: Agents 2 (auth), 4 (inventory)
## Priority: CRITICAL - Required for Agent 9 (Flutter POS UI)

---

## Mission
Build the sales processing API with atomic transactions, inventory decrements, receipt generation, and image uploads.

---

## Deliverables Checklist

### 1. Sales Models
**File**: `backend/models/sale.go`

```go
package models

import "github.com/google/uuid"

type Sale struct {
    BaseModel
    OrganizationID   uuid.UUID  `gorm:"not null;index" json:"organization_id"`
    UserID           uuid.UUID  `gorm:"not null" json:"user_id"`
    TotalAmount      float64    `gorm:"not null" json:"total_amount"`
    TotalProfit      float64    `gorm:"not null" json:"total_profit"`
    PaymentMethod    string     `gorm:"not null" json:"payment_method"`
    PaymentProofURL  string     `json:"payment_proof_url"`
    IsSynced         bool       `gorm:"not null;default:true" json:"is_synced"`
    User             User       `gorm:"foreignKey:UserID" json:"user,omitempty"`
    Items            []SaleItem `gorm:"foreignKey:SaleID;constraint:OnDelete:CASCADE" json:"items,omitempty"`
}

type SaleItem struct {
    BaseModel
    SaleID               uuid.UUID `gorm:"not null;index" json:"sale_id"`
    VariantID            uuid.UUID `gorm:"not null" json:"variant_id"`
    Quantity             int       `gorm:"not null" json:"quantity"`
    PriceAtSale          float64   `gorm:"not null" json:"price_at_sale"`
    PurchasePriceAtSale  float64   `gorm:"not null" json:"purchase_price_at_sale"`
    Variant              Variant   `gorm:"foreignKey:VariantID" json:"variant,omitempty"`
}
```

### 2. Sales Handlers
**File**: `backend/handlers/sales.go`

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

type CreateSaleRequest struct {
    PaymentMethod string             `json:"payment_method" binding:"required"`
    Items         []SaleItemRequest  `json:"items" binding:"required,min=1"`
}

type SaleItemRequest struct {
    VariantID string `json:"variant_id" binding:"required"`
    Quantity  int    `json:"quantity" binding:"required,gt=0"`
}

// ProcessSale creates a new sale and decrements inventory atomically
func ProcessSale(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)
    userID := c.MustGet("user_id").(uuid.UUID)

    var req CreateSaleRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // Start atomic transaction
    tx := database.DB.Begin()
    defer func() {
        if r := recover(); r != nil {
            tx.Rollback()
        }
    }()

    var totalAmount float64
    var totalProfit float64
    var saleItems []models.SaleItem

    // Process each item
    for _, itemReq := range req.Items {
        variantID, err := uuid.Parse(itemReq.VariantID)
        if err != nil {
            tx.Rollback()
            c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid variant ID: " + itemReq.VariantID})
            return
        }

        // Lock variant row for update
        var variant models.Variant
        if err := tx.Set("gorm:query_option", "FOR UPDATE").
            Joins("JOIN products ON products.id = variants.product_id").
            Where("variants.id = ? AND products.organization_id = ?", variantID, orgID).
            First(&variant).Error; err != nil {
            tx.Rollback()
            c.JSON(http.StatusNotFound, gin.H{"error": "Variant not found: " + itemReq.VariantID})
            return
        }

        // Check stock availability
        if variant.Quantity < itemReq.Quantity {
            tx.Rollback()
            c.JSON(http.StatusBadRequest, gin.H{
                "error":     "Insufficient stock",
                "variant_id": variantID.String(),
                "available":  variant.Quantity,
                "requested":  itemReq.Quantity,
            })
            return
        }

        // Calculate amounts
        itemTotal := variant.SalePrice * float64(itemReq.Quantity)
        itemCost := variant.PurchasePrice * float64(itemReq.Quantity)
        itemProfit := itemTotal - itemCost

        totalAmount += itemTotal
        totalProfit += itemProfit

        // Decrement stock
        variant.Quantity -= itemReq.Quantity
        if err := tx.Save(&variant).Error; err != nil {
            tx.Rollback()
            c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update stock"})
            return
        }

        // Prepare sale item
        saleItems = append(saleItems, models.SaleItem{
            VariantID:           variantID,
            Quantity:            itemReq.Quantity,
            PriceAtSale:         variant.SalePrice,
            PurchasePriceAtSale: variant.PurchasePrice,
        })
    }

    // Create sale record
    sale := models.Sale{
        OrganizationID: orgID,
        UserID:         userID,
        TotalAmount:    totalAmount,
        TotalProfit:    totalProfit,
        PaymentMethod:  req.PaymentMethod,
        IsSynced:       true,
    }

    if err := tx.Create(&sale).Error; err != nil {
        tx.Rollback()
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create sale"})
        return
    }

    // Create sale items
    for i := range saleItems {
        saleItems[i].SaleID = sale.ID
        if err := tx.Create(&saleItems[i]).Error; err != nil {
            tx.Rollback()
            c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create sale items"})
            return
        }
    }

    // Commit transaction
    if err := tx.Commit().Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete sale"})
        return
    }

    // Reload with associations
    database.DB.Preload("Items.Variant.Product").Preload("User").First(&sale, sale.ID)
    c.JSON(http.StatusCreated, sale)
}

// ListSales returns paginated sales history
func ListSales(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)

    // Pagination
    page := 1
    limit := 50
    if p := c.Query("page"); p != "" {
        fmt.Sscanf(p, "%d", &page)
    }
    if l := c.Query("limit"); l != "" {
        fmt.Sscanf(l, "%d", &limit)
    }
    offset := (page - 1) * limit

    // Date filters
    startDate := c.Query("start_date")
    endDate := c.Query("end_date")

    query := database.DB.Where("organization_id = ?", orgID)

    if startDate != "" {
        start, _ := time.Parse("2006-01-02", startDate)
        query = query.Where("created_at >= ?", start)
    }
    if endDate != "" {
        end, _ := time.Parse("2006-01-02", endDate)
        query = query.Where("created_at <= ?", end.Add(24*time.Hour))
    }

    var sales []models.Sale
    var total int64

    query.Model(&models.Sale{}).Count(&total)
    if err := query.
        Preload("Items.Variant.Product").
        Preload("User").
        Order("created_at DESC").
        Limit(limit).
        Offset(offset).
        Find(&sales).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sales"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "sales":       sales,
        "total":       total,
        "page":        page,
        "limit":       limit,
        "total_pages": (total + int64(limit) - 1) / int64(limit),
    })
}

// GetSale returns a single sale with details
func GetSale(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)
    saleID, err := uuid.Parse(c.Param("id"))
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

    c.JSON(http.StatusOK, sale)
}

// UploadPaymentProof handles payment proof image upload
func UploadPaymentProof(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)
    saleID, err := uuid.Parse(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid sale ID"})
        return
    }

    var sale models.Sale
    if err := database.DB.Where("id = ? AND organization_id = ?", saleID, orgID).
        First(&sale).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Sale not found"})
        return
    }

    file, err := c.FormFile("image")
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "No image file provided"})
        return
    }

    // Save file locally (in production, use S3 or similar)
    filename := fmt.Sprintf("payment_proof_%s_%s", saleID.String(), file.Filename)
    filepath := fmt.Sprintf("./uploads/%s", filename)

    if err := c.SaveUploadedFile(file, filepath); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save image"})
        return
    }

    // Update sale record
    sale.PaymentProofURL = filepath
    if err := database.DB.Save(&sale).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update sale"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "message": "Payment proof uploaded",
        "url":     filepath,
    })
}
```

### 3. Receipt Service
**File**: `backend/services/receipt_service.go`

```go
package services

import (
    "bstock/models"
    "bytes"
    "fmt"
    "time"
)

type ReceiptService struct{}

func NewReceiptService() *ReceiptService {
    return &ReceiptService{}
}

// GenerateReceipt generates a simple text receipt (PDF in production)
func (s *ReceiptService) GenerateReceipt(sale *models.Sale, org *models.Organization) ([]byte, error) {
    var buf bytes.Buffer

    buf.WriteString("===============================\n")
    buf.WriteString(fmt.Sprintf("     %s\n", org.Name))
    buf.WriteString("===============================\n\n")
    buf.WriteString(fmt.Sprintf("Receipt #: %s\n", sale.ID.String()[:8]))
    buf.WriteString(fmt.Sprintf("Date: %s\n", sale.CreatedAt.Format("2006-01-02 15:04:05")))
    buf.WriteString(fmt.Sprintf("Cashier: %s\n", sale.User.PhoneNumber))
    buf.WriteString("\n-------------------------------\n")
    buf.WriteString("ITEMS\n")
    buf.WriteString("-------------------------------\n")

    for _, item := range sale.Items {
        productName := "Unknown"
        if item.Variant.Product.Name != "" {
            productName = item.Variant.Product.Name
        }
        buf.WriteString(fmt.Sprintf("%dx %s\n", item.Quantity, productName))
        buf.WriteString(fmt.Sprintf("   @ %.2f = %.2f\n", item.PriceAtSale, float64(item.Quantity)*item.PriceAtSale))
    }

    buf.WriteString("\n-------------------------------\n")
    buf.WriteString(fmt.Sprintf("TOTAL: %.2f ETB\n", sale.TotalAmount))
    buf.WriteString(fmt.Sprintf("Payment: %s\n", sale.PaymentMethod))
    buf.WriteString("-------------------------------\n\n")
    buf.WriteString("Thank you for your business!\n")
    buf.WriteString("===============================\n")

    return buf.Bytes(), nil
}
```

### 4. Receipt Handler
**File**: `backend/handlers/receipts.go`

```go
package handlers

import (
    "bstock/database"
    "bstock/models"
    "bstock/services"
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
```

### 5. Update Routes
**File**: `backend/routes/routes.go` (ADD)

```go
// Sales
sales := protected.Group("/sales")
{
    sales.POST("", handlers.ProcessSale)
    sales.GET("", handlers.ListSales)
    sales.GET("/:id", handlers.GetSale)
    sales.POST("/:id/upload-proof", handlers.UploadPaymentProof)
}

// Receipts
receipts := protected.Group("/receipts")
{
    receipts.GET("/:sale_id/pdf", handlers.GetReceipt)
}
```

### 6. Create Uploads Directory
**File**: `backend/cmd/server/main.go` (UPDATE)

```go
import "os"

func main() {
    // Create uploads directory
    os.MkdirAll("./uploads", 0755)

    // ... rest of main
}
```

---

## Testing Checklist

```bash
# Process a sale
curl -X POST http://localhost:8080/api/v1/sales \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "payment_method": "Cash",
    "items": [
      {"variant_id": "<VARIANT_ID_1>", "quantity": 2},
      {"variant_id": "<VARIANT_ID_2>", "quantity": 1}
    ]
  }'

# List sales
curl -X GET "http://localhost:8080/api/v1/sales?page=1&limit=10" \
  -H "Authorization: Bearer <TOKEN>"

# Get single sale
curl -X GET http://localhost:8080/api/v1/sales/<SALE_ID> \
  -H "Authorization: Bearer <TOKEN>"

# Upload payment proof
curl -X POST http://localhost:8080/api/v1/sales/<SALE_ID>/upload-proof \
  -H "Authorization: Bearer <TOKEN>" \
  -F "image=@/path/to/image.jpg"

# Get receipt
curl -X GET http://localhost:8080/api/v1/receipts/<SALE_ID>/pdf \
  -H "Authorization: Bearer <TOKEN>" \
  --output receipt.txt
```

- [ ] Sale processes atomically
- [ ] Stock decrements correctly
- [ ] Insufficient stock rejected
- [ ] Total calculations accurate
- [ ] Profit calculated correctly
- [ ] Sales list with pagination
- [ ] Receipt generation works
- [ ] Payment proof upload works
- [ ] Multi-user sales tracked

---

## Success Criteria

1. ✅ Atomic sale transactions
2. ✅ Inventory decrements automatically
3. ✅ Receipt generation
4. ✅ Payment proof uploads
5. ✅ Sales history and filtering
6. ✅ No race conditions in stock updates

**Estimated Completion: 8-10 hours**
