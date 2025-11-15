package database

import (
	"bstock/models"
	"gorm.io/gorm"
)

func SeedDatabase(db *gorm.DB) error {
	// Seed Plans
	plans := []models.Plan{
		{
			Name:             "free",
			PriceMonthly:     0,
			ProductLimit:     intPtr(15),
			UserLimit:        intPtr(2),
			LocationLimit:    intPtr(1),
			AnalyticsEnabled: false,
		},
		{
			Name:             "growth",
			PriceMonthly:     299.99,
			ProductLimit:     intPtr(500),
			UserLimit:        intPtr(10),
			LocationLimit:    intPtr(3),
			AnalyticsEnabled: true,
		},
		{
			Name:             "pro",
			PriceMonthly:     999.99,
			ProductLimit:     nil, // unlimited
			UserLimit:        nil, // unlimited
			LocationLimit:    nil, // unlimited
			AnalyticsEnabled: true,
		},
	}

	for _, plan := range plans {
		if err := db.FirstOrCreate(&plan, models.Plan{Name: plan.Name}).Error; err != nil {
			return err
		}
	}

	return nil
}

func intPtr(i int) *int {
	return &i
}
