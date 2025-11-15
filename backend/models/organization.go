package models

import "github.com/google/uuid"

type Organization struct {
	BaseModel
	Name           string        `gorm:"uniqueIndex;not null" json:"name"`
	OwnerID        uuid.UUID     `gorm:"not null" json:"owner_id"`
	SubscriptionID *uuid.UUID    `json:"subscription_id,omitempty"`
	Owner          User          `gorm:"foreignKey:OwnerID" json:"owner,omitempty"`
	Subscription   *Subscription `gorm:"foreignKey:SubscriptionID" json:"subscription,omitempty"`
	Users          []User        `gorm:"many2many:organization_users;" json:"users,omitempty"`
}
