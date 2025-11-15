# Agent 6: Backend - Analytics & Reporting API

## Timeline: Day 2 (Start after Agent 5, parallel with Flutter agents)
## Dependencies: Agents 2 (auth), 3 (plan enforcement), 5 (sales data)
## Priority: MEDIUM - Required for Agent 10 (Flutter Analytics UI)

---

## Mission
Build analytics endpoints with revenue, profit, and product performance reports. Must be feature-gated for non-free plans.

---

## Deliverables Checklist

### 1. Analytics Service
**File**: `backend/services/analytics_service.go`

```go
package services

import (
    "bstock/database"
    "bstock/models"
    "time"
    "github.com/google/uuid"
)

type AnalyticsService struct{}

func NewAnalyticsService() *AnalyticsService {
    return &AnalyticsService{}
}

type Summary struct {
    TotalRevenue    float64 `json:"total_revenue"`
    TotalCost       float64 `json:"total_cost"`
    GrossProfit     float64 `json:"gross_profit"`
    TransactionCount int64   `json:"transaction_count"`
    ItemsSold       int64   `json:"items_sold"`
}

// GetSummary returns aggregated metrics for a date range
func (s *AnalyticsService) GetSummary(orgID uuid.UUID, startDate, endDate time.Time) (*Summary, error) {
    var summary Summary

    query := database.DB.Model(&models.Sale{}).
        Where("organization_id = ?", orgID).
        Where("created_at >= ? AND created_at <= ?", startDate, endDate)

    // Aggregate sales
    type Result struct {
        TotalRevenue float64
        TotalProfit  float64
        Count        int64
    }

    var result Result
    if err := query.
        Select("SUM(total_amount) as total_revenue, SUM(total_profit) as total_profit, COUNT(*) as count").
        Scan(&result).Error; err != nil {
        return nil, err
    }

    summary.TotalRevenue = result.TotalRevenue
    summary.GrossProfit = result.TotalProfit
    summary.TotalCost = result.TotalRevenue - result.TotalProfit
    summary.TransactionCount = result.Count

    // Count items sold
    var itemsResult struct {
        TotalItems int64
    }
    database.DB.Model(&models.SaleItem{}).
        Joins("JOIN sales ON sales.id = sale_items.sale_id").
        Where("sales.organization_id = ?", orgID).
        Where("sales.created_at >= ? AND sales.created_at <= ?", startDate, endDate).
        Select("SUM(sale_items.quantity) as total_items").
        Scan(&itemsResult)

    summary.ItemsSold = itemsResult.TotalItems

    return &summary, nil
}

type ProductPerformance struct {
    ProductID    uuid.UUID `json:"product_id"`
    ProductName  string    `json:"product_name"`
    VariantID    uuid.UUID `json:"variant_id"`
    SKU          string    `json:"sku"`
    TotalQuantity int      `json:"total_quantity"`
    TotalRevenue float64   `json:"total_revenue"`
    TotalProfit  float64   `json:"total_profit"`
}

// GetTopSellingProducts returns products ranked by quantity sold
func (s *AnalyticsService) GetTopSellingProducts(orgID uuid.UUID, startDate, endDate time.Time, limit int) ([]ProductPerformance, error) {
    var results []ProductPerformance

    err := database.DB.Raw(`
        SELECT
            products.id as product_id,
            products.name as product_name,
            variants.id as variant_id,
            variants.sku as sku,
            SUM(sale_items.quantity) as total_quantity,
            SUM(sale_items.quantity * sale_items.price_at_sale) as total_revenue,
            SUM(sale_items.quantity * (sale_items.price_at_sale - sale_items.purchase_price_at_sale)) as total_profit
        FROM sale_items
        JOIN variants ON variants.id = sale_items.variant_id
        JOIN products ON products.id = variants.product_id
        JOIN sales ON sales.id = sale_items.sale_id
        WHERE sales.organization_id = ?
          AND sales.created_at >= ?
          AND sales.created_at <= ?
        GROUP BY products.id, products.name, variants.id, variants.sku
        ORDER BY total_quantity DESC
        LIMIT ?
    `, orgID, startDate, endDate, limit).Scan(&results).Error

    return results, err
}

// GetMostProfitableProducts returns products ranked by profit
func (s *AnalyticsService) GetMostProfitableProducts(orgID uuid.UUID, startDate, endDate time.Time, limit int) ([]ProductPerformance, error) {
    var results []ProductPerformance

    err := database.DB.Raw(`
        SELECT
            products.id as product_id,
            products.name as product_name,
            variants.id as variant_id,
            variants.sku as sku,
            SUM(sale_items.quantity) as total_quantity,
            SUM(sale_items.quantity * sale_items.price_at_sale) as total_revenue,
            SUM(sale_items.quantity * (sale_items.price_at_sale - sale_items.purchase_price_at_sale)) as total_profit
        FROM sale_items
        JOIN variants ON variants.id = sale_items.variant_id
        JOIN products ON products.id = variants.product_id
        JOIN sales ON sales.id = sale_items.sale_id
        WHERE sales.organization_id = ?
          AND sales.created_at >= ?
          AND sales.created_at <= ?
        GROUP BY products.id, products.name, variants.id, variants.sku
        ORDER BY total_profit DESC
        LIMIT ?
    `, orgID, startDate, endDate, limit).Scan(&results).Error

    return results, err
}

type DailySales struct {
    Date       string  `json:"date"`
    Revenue    float64 `json:"revenue"`
    Profit     float64 `json:"profit"`
    Transactions int   `json:"transactions"`
}

// GetDailySales returns daily breakdown for charting
func (s *AnalyticsService) GetDailySales(orgID uuid.UUID, startDate, endDate time.Time) ([]DailySales, error) {
    var results []DailySales

    err := database.DB.Raw(`
        SELECT
            DATE(created_at) as date,
            SUM(total_amount) as revenue,
            SUM(total_profit) as profit,
            COUNT(*) as transactions
        FROM sales
        WHERE organization_id = ?
          AND created_at >= ?
          AND created_at <= ?
        GROUP BY DATE(created_at)
        ORDER BY date ASC
    `, orgID, startDate, endDate).Scan(&results).Error

    return results, err
}
```

### 2. Analytics Handlers
**File**: `backend/handlers/analytics.go`

```go
package handlers

import (
    "bstock/services"
    "net/http"
    "time"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
)

// GetAnalyticsSummary returns key business metrics
func GetAnalyticsSummary(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)

    // Parse date range
    startDateStr := c.Query("start_date")
    endDateStr := c.Query("end_date")

    var startDate, endDate time.Time
    var err error

    if startDateStr == "" {
        // Default to last 30 days
        startDate = time.Now().AddDate(0, 0, -30)
    } else {
        startDate, err = time.Parse("2006-01-02", startDateStr)
        if err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start_date format"})
            return
        }
    }

    if endDateStr == "" {
        endDate = time.Now()
    } else {
        endDate, err = time.Parse("2006-01-02", endDateStr)
        if err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end_date format"})
            return
        }
    }

    // Ensure endDate is end of day
    endDate = endDate.Add(24 * time.Hour).Add(-time.Second)

    analyticsService := services.NewAnalyticsService()
    summary, err := analyticsService.GetSummary(orgID, startDate, endDate)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch analytics"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "summary":    summary,
        "start_date": startDate.Format("2006-01-02"),
        "end_date":   endDate.Format("2006-01-02"),
    })
}

// GetTopProducts returns top selling products
func GetTopProducts(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)

    // Parse parameters
    sortBy := c.DefaultQuery("sort_by", "quantity") // quantity or profit
    limit := 10
    if l := c.Query("limit"); l != "" {
        fmt.Sscanf(l, "%d", &limit)
    }

    startDate := time.Now().AddDate(0, 0, -30)
    endDate := time.Now()

    if sd := c.Query("start_date"); sd != "" {
        startDate, _ = time.Parse("2006-01-02", sd)
    }
    if ed := c.Query("end_date"); ed != "" {
        endDate, _ = time.Parse("2006-01-02", ed)
        endDate = endDate.Add(24 * time.Hour).Add(-time.Second)
    }

    analyticsService := services.NewAnalyticsService()
    var products []services.ProductPerformance
    var err error

    if sortBy == "profit" {
        products, err = analyticsService.GetMostProfitableProducts(orgID, startDate, endDate, limit)
    } else {
        products, err = analyticsService.GetTopSellingProducts(orgID, startDate, endDate, limit)
    }

    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch top products"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "products":   products,
        "sort_by":    sortBy,
        "start_date": startDate.Format("2006-01-02"),
        "end_date":   endDate.Format("2006-01-02"),
    })
}

// GetDailySalesChart returns daily sales data for charting
func GetDailySalesChart(c *gin.Context) {
    orgID := c.MustGet("organization_id").(uuid.UUID)

    startDate := time.Now().AddDate(0, 0, -30)
    endDate := time.Now()

    if sd := c.Query("start_date"); sd != "" {
        startDate, _ = time.Parse("2006-01-02", sd)
    }
    if ed := c.Query("end_date"); ed != "" {
        endDate, _ = time.Parse("2006-01-02", ed)
        endDate = endDate.Add(24 * time.Hour).Add(-time.Second)
    }

    analyticsService := services.NewAnalyticsService()
    dailySales, err := analyticsService.GetDailySales(orgID, startDate, endDate)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch daily sales"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "daily_sales": dailySales,
        "start_date":  startDate.Format("2006-01-02"),
        "end_date":    endDate.Format("2006-01-02"),
    })
}
```

### 3. Update Routes
**File**: `backend/routes/routes.go` (ADD)

```go
// Analytics (Owner only, requires analytics enabled plan)
analytics := protected.Group("/analytics")
analytics.Use(middleware.RequireRole("owner"))
analytics.Use(middleware.RequireAnalytics())
{
    analytics.GET("/summary", handlers.GetAnalyticsSummary)
    analytics.GET("/products/top", handlers.GetTopProducts)
    analytics.GET("/sales/daily", handlers.GetDailySalesChart)
}
```

---

## Testing Checklist

```bash
# Get summary (last 30 days)
curl -X GET "http://localhost:8080/api/v1/analytics/summary" \
  -H "Authorization: Bearer <OWNER_TOKEN>"

# Get summary for date range
curl -X GET "http://localhost:8080/api/v1/analytics/summary?start_date=2025-01-01&end_date=2025-01-31" \
  -H "Authorization: Bearer <OWNER_TOKEN>"

# Get top selling products
curl -X GET "http://localhost:8080/api/v1/analytics/products/top?sort_by=quantity&limit=10" \
  -H "Authorization: Bearer <OWNER_TOKEN>"

# Get most profitable products
curl -X GET "http://localhost:8080/api/v1/analytics/products/top?sort_by=profit&limit=10" \
  -H "Authorization: Bearer <OWNER_TOKEN>"

# Get daily sales chart
curl -X GET "http://localhost:8080/api/v1/analytics/sales/daily?start_date=2025-01-01&end_date=2025-01-31" \
  -H "Authorization: Bearer <OWNER_TOKEN>"

# Test with free plan (should fail)
# 1. Set to free plan
# 2. Try analytics endpoint
# Expected: 403 Forbidden with upgrade message

# Test with cashier role (should fail)
# Expected: 403 Forbidden (owner only)
```

- [ ] Summary calculations accurate
- [ ] Top products sorted correctly
- [ ] Daily breakdown correct
- [ ] Free plan blocked
- [ ] Cashier role blocked
- [ ] Owner on paid plan has access
- [ ] Date range filtering works
- [ ] Aggregations performant

---

## Success Criteria

1. ✅ Revenue and profit tracking
2. ✅ Product performance reports
3. ✅ Daily sales charting
4. ✅ Feature gate enforced
5. ✅ Role-based access working
6. ✅ Efficient SQL queries

**Estimated Completion: 6-8 hours**
