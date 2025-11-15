package models

import "github.com/google/uuid"

type Sale struct {
	BaseModel
	OrganizationID  uuid.UUID  `gorm:"not null;index" json:"organization_id"`
	UserID          uuid.UUID  `gorm:"not null" json:"user_id"`
	TotalAmount     float64    `gorm:"not null" json:"total_amount"`
	TotalProfit     float64    `gorm:"not null" json:"total_profit"`
	PaymentMethod   string     `gorm:"not null" json:"payment_method"`
	PaymentProofURL string     `json:"payment_proof_url"`
	IsSynced        bool       `gorm:"not null;default:true" json:"is_synced"`
	User            User       `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Items           []SaleItem `gorm:"foreignKey:SaleID;constraint:OnDelete:CASCADE" json:"items,omitempty"`
}

type SaleItem struct {
	BaseModel
	SaleID              uuid.UUID `gorm:"not null;index" json:"sale_id"`
	VariantID           uuid.UUID `gorm:"not null" json:"variant_id"`
	Quantity            int       `gorm:"not null" json:"quantity"`
	PriceAtSale         float64   `gorm:"not null" json:"price_at_sale"`
	PurchasePriceAtSale float64   `gorm:"not null" json:"purchase_price_at_sale"`
	Variant             Variant   `gorm:"foreignKey:VariantID" json:"variant,omitempty"`
}
