package models

type Plan struct {
	BaseModel
	Name             string  `gorm:"uniqueIndex;not null" json:"name"`
	PriceMonthly     float64 `gorm:"not null" json:"price_monthly"`
	ProductLimit     *int    `json:"product_limit"`
	UserLimit        *int    `json:"user_limit"`
	LocationLimit    *int    `json:"location_limit"`
	AnalyticsEnabled bool    `gorm:"default:false" json:"analytics_enabled"`
}
