package main

import (
	"bstock/database"
	"bstock/models"
	"bstock/routes"
	"github.com/gin-gonic/gin"
	"log"
	"os"
	"strings"
)

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
		if allowedOrigins == "" {
			allowedOrigins = "http://localhost:3000,http://localhost:8080"
		}

		origin := c.Request.Header.Get("Origin")
		origins := strings.Split(allowedOrigins, ",")

		// Check if origin is allowed
		allowed := false
		for _, o := range origins {
			if strings.TrimSpace(o) == origin {
				allowed = true
				break
			}
		}

		if allowed {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
		}

		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func main() {
	// Set Gin mode from environment
	ginMode := os.Getenv("GIN_MODE")
	if ginMode != "" {
		gin.SetMode(ginMode)
	}

	// Create uploads directory
	if err := os.MkdirAll("./uploads", 0755); err != nil {
		log.Fatal("Failed to create uploads directory:", err)
	}

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
		&models.Sale{},
		&models.SaleItem{},
	); err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	// Seed database
	if err := database.SeedDatabase(database.DB); err != nil {
		log.Fatal("Failed to seed database:", err)
	}

	log.Println("✅ Database migrated and seeded successfully")

	// Setup Gin router
	r := gin.Default()
	r.Use(gin.Recovery())
	r.Use(CORSMiddleware())

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "ok",
			"service": "bstock-api",
			"version": "1.0.0",
		})
	})

	// Setup API routes
	routes.SetupRoutes(r)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 Server starting on port %s...\n", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
