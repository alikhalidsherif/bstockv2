package main

import (
	"bstock/database"
	"log"
	"github.com/gin-gonic/gin"
)

func main() {
	// Connect to database
	if err := database.Connect(); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Seed database
	if err := database.SeedDatabase(database.DB); err != nil {
		log.Fatal("Failed to seed database:", err)
	}

	// Setup Gin router
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Start server
	if err := r.Run(":8080"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
