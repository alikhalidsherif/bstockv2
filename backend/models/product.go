package models

import "github.com/google/uuid"

type Product struct {
	BaseModel
	OrganizationID uuid.UUID  `gorm:"not null;index" json:"organization_id"`
	Name           string     `gorm:"not null" json:"name"`
	Description    string     `json:"description"`
	Category       string     `json:"category"`
	ImageURL       string     `json:"image_url"`
	VendorID       *uuid.UUID `json:"vendor_id,omitempty"`
	Vendor         *Vendor    `gorm:"foreignKey:VendorID" json:"vendor,omitempty"`
	Variants       []Variant  `gorm:"foreignKey:ProductID;constraint:OnDelete:CASCADE" json:"variants,omitempty"`
}

type Variant struct {
	BaseModel
	ProductID     uuid.UUID         `gorm:"not null;index" json:"product_id"`
	Attributes    map[string]string `gorm:"type:jsonb;default:'{}'" json:"attributes"` // e.g., {"Size": "L", "Color": "Red"}
	SKU           string            `gorm:"not null" json:"sku"`
	PurchasePrice float64           `gorm:"not null;default:0" json:"purchase_price"`
	SalePrice     float64           `gorm:"not null" json:"sale_price"`
	Quantity      int               `gorm:"not null;default:0" json:"quantity"`
	MinStockLevel int               `gorm:"default:0" json:"min_stock_level"`
	UnitType      string            `gorm:"default:'pcs'" json:"unit_type"` // pcs, kg, L, etc.
	Product       Product           `gorm:"foreignKey:ProductID" json:"product,omitempty"`
}

type Vendor struct {
	BaseModel
	OrganizationID uuid.UUID `gorm:"not null;index" json:"organization_id"`
	Name           string    `gorm:"not null" json:"name"`
	ContactInfo    string    `json:"contact_info"`
}
