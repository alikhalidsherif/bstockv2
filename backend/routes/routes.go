package routes

import (
	"bstock/handlers"
	"bstock/middleware"
	"github.com/gin-gonic/gin"
)

func SetupRoutes(r *gin.Engine) {
	api := r.Group("/api/v1")
	{
		// Public routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", handlers.Register)
			auth.POST("/login", handlers.Login)
		}

		// Webhooks (public, but validated in handler)
		api.POST("/webhooks/payment", handlers.HandlePaymentWebhook)

		// Protected routes
		protected := api.Group("")
		protected.Use(middleware.AuthRequired())
		{
			// Subscriptions
			subscriptions := protected.Group("/subscriptions")
			{
				subscriptions.GET("/plans", handlers.ListPlans)
				subscriptions.GET("/current", handlers.GetCurrentSubscription)
				subscriptions.POST("/change-plan", middleware.RequireRole("owner"), handlers.ChangePlan)

				// Debug endpoint
				subscriptions.POST("/dev/set-plan/:plan_name", handlers.DevSetPlan)
			}

			// User management (Owner only)
			users := protected.Group("/users")
			users.Use(middleware.RequireRole("owner"))
			{
				users.GET("", handlers.ListUsers)
				users.POST("/invite", middleware.CheckUserLimit, handlers.InviteUser)
				users.DELETE("/:id", handlers.RemoveUser)
			}

			// Products
			products := protected.Group("/products")
			{
				products.GET("", handlers.ListProducts)
				products.POST("", middleware.CheckProductLimit, handlers.CreateProduct)
				products.GET("/:id", handlers.GetProduct)
				products.PUT("/:id", handlers.UpdateProduct)
				products.DELETE("/:id", middleware.RequireRole("owner"), handlers.DeleteProduct)
			}

			// Variants
			variants := protected.Group("/variants")
			{
				variants.PUT("/:id", handlers.UpdateVariant)
				variants.POST("/:id/adjust-stock", handlers.AdjustStock)
				variants.GET("/low-stock", handlers.GetLowStockAlerts)
			}

			// Vendors
			vendors := protected.Group("/vendors")
			{
				vendors.GET("", handlers.ListVendors)
				vendors.POST("", handlers.CreateVendor)
				vendors.DELETE("/:id", handlers.DeleteVendor)
			}

			// Sales
			sales := protected.Group("/sales")
			{
				sales.POST("", handlers.ProcessSale)
				sales.GET("", handlers.ListSales)
				sales.GET("/:id", handlers.GetSale)
				sales.POST("/:id/upload-proof", handlers.UploadPaymentProof)
			}

			// Receipts
			receipts := protected.Group("/receipts")
			{
				receipts.GET("/:sale_id/pdf", handlers.GetReceipt)
			}

			// Analytics (Owner only, requires analytics enabled plan)
			analytics := protected.Group("/analytics")
			analytics.Use(middleware.RequireRole("owner"))
			analytics.Use(middleware.RequireAnalytics())
			{
				analytics.GET("/summary", handlers.GetAnalyticsSummary)
				analytics.GET("/products/top", handlers.GetTopProducts)
				analytics.GET("/sales/daily", handlers.GetDailySalesChart)
			}
		}
	}
}
