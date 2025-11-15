package main

import (
	"bstock/database"
	"bstock/models"
	"bstock/routes"
	"github.com/gin-gonic/gin"
	"log"
)

func main() {
	// Connect to database
	if err := database.Connect(); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Auto-migrate models
	if err := database.DB.AutoMigrate(
		&models.User{},
		&models.Organization{},
		&models.OrganizationUser{},
		&models.Plan{},
		&models.Subscription{},
		&models.Product{},
		&models.Variant{},
		&models.Vendor{},
	); err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	// Seed database
	if err := database.SeedDatabase(database.DB); err != nil {
		log.Fatal("Failed to seed database:", err)
	}

	// Setup Gin router
	r := gin.Default()
	r.Use(gin.Recovery())

	// Setup routes
	routes.SetupRoutes(r)

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Start server
	if err := r.Run(":8080"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
