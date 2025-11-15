package models

import (
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type User struct {
	BaseModel
	PhoneNumber   string         `gorm:"uniqueIndex;not null" json:"phone_number"`
	PasswordHash  string         `gorm:"not null" json:"-"`
	Organizations []Organization `gorm:"many2many:organization_users;" json:"organizations,omitempty"`
}

type OrganizationUser struct {
	BaseModel
	UserID         uuid.UUID    `gorm:"not null" json:"user_id"`
	OrganizationID uuid.UUID    `gorm:"not null" json:"organization_id"`
	Role           string       `gorm:"not null;check:role IN ('owner', 'cashier')" json:"role"`
	User           User         `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Organization   Organization `gorm:"foreignKey:OrganizationID" json:"organization,omitempty"`
}

func (u *User) SetPassword(password string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	u.PasswordHash = string(hash)
	return nil
}

func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password))
	return err == nil
}
