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
