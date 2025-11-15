package handlers

import (
	"bstock/services"
	"fmt"
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
