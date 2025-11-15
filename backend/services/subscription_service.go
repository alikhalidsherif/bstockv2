package services

import (
	"bstock/database"
	"bstock/models"
	"errors"

	"github.com/google/uuid"
)

type SubscriptionService struct{}

func NewSubscriptionService() *SubscriptionService {
	return &SubscriptionService{}
}

// GetOrganizationPlan retrieves the plan for an organization
func (s *SubscriptionService) GetOrganizationPlan(orgID uuid.UUID) (*models.Plan, error) {
	var org models.Organization
	if err := database.DB.Preload("Subscription.Plan").First(&org, orgID).Error; err != nil {
		return nil, err
	}

	if org.Subscription == nil {
		return nil, errors.New("no subscription found")
	}

	return &org.Subscription.Plan, nil
}

// CanAddProduct checks if organization can add more products
func (s *SubscriptionService) CanAddProduct(orgID uuid.UUID) (bool, error) {
	plan, err := s.GetOrganizationPlan(orgID)
	if err != nil {
		return false, err
	}

	if plan.ProductLimit == nil {
		return true, nil // Unlimited
	}

	var count int64
	if err := database.DB.Model(&models.Product{}).
		Where("organization_id = ?", orgID).
		Count(&count).Error; err != nil {
		return false, err
	}

	return count < int64(*plan.ProductLimit), nil
}

// CanAddUser checks if organization can add more users
func (s *SubscriptionService) CanAddUser(orgID uuid.UUID) (bool, error) {
	plan, err := s.GetOrganizationPlan(orgID)
	if err != nil {
		return false, err
	}

	if plan.UserLimit == nil {
		return true, nil // Unlimited
	}

	var count int64
	if err := database.DB.Model(&models.OrganizationUser{}).
		Where("organization_id = ?", orgID).
		Count(&count).Error; err != nil {
		return false, err
	}

	return count < int64(*plan.UserLimit), nil
}

// HasAnalyticsAccess checks if organization can access analytics
func (s *SubscriptionService) HasAnalyticsAccess(orgID uuid.UUID) (bool, error) {
	plan, err := s.GetOrganizationPlan(orgID)
	if err != nil {
		return false, err
	}

	return plan.AnalyticsEnabled, nil
}
