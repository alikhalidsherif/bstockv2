package models

import (
	"github.com/google/uuid"
	"time"
)

type Subscription struct {
	BaseModel
	OrganizationID   uuid.UUID  `gorm:"uniqueIndex;not null" json:"organization_id"`
	PlanID           uuid.UUID  `gorm:"not null" json:"plan_id"`
	Status           string     `gorm:"not null;check:status IN ('active', 'trial', 'canceled')" json:"status"`
	CurrentPeriodEnd *time.Time `json:"current_period_end,omitempty"`
	Plan             Plan       `gorm:"foreignKey:PlanID" json:"plan,omitempty"`
}
