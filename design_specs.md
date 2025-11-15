---

### **System Design & Technical Specification: Bstock**

*   **Document Version:** 1.0
*   **Project Title:** Bstock - System & Technical Specification
*   **Date:** November 5, 2025
*   **Reference:** Master Project Brief v1.0, Functional Requirements Document v1.0

#### **1.0 System Architecture & Technology Stack**

*   **1.1 Architecture Overview:** The system will be a classic client-server architecture. The frontend is a cross-platform mobile and web application. The backend is a stateless RESTful API service connected to a relational database. All services will be containerized for portability and consistent deployment.

*   **1.2 Technology Stack:**
    *   **Frontend (Client):**
        *   **Framework:** Flutter
        *   **State Management:** Provider / Riverpod
        *   **Local Database:** Isar (for offline caching and queuing)
        *   **Navigation:** GoRouter
    *   **Backend (Server):**
        *   **Language/Framework:** Go (Golang) with the Gin web framework.
        *   **Database ORM:** GORM
    *   **Database:**
        *   **Primary:** PostgreSQL (Production & Staging)
        *   **Security:** Row-Level Security (RLS) will be implemented to enforce multi-tenancy at the database level.
    *   **Infrastructure & Deployment:**
        *   **Containerization:** Docker & Docker Compose
        *   **CI/CD:** GitHub Actions with a self-hosted runner.
        *   **Reverse Proxy:** Nginx Proxy Manager (on the host server).

#### **2.0 Database Schema (PostgreSQL)**

This section defines the final structure of all database tables. `id` is the primary key (UUID) and `created_at`/`updated_at` timestamps are assumed for all tables.

*   **`organizations`**
    *   `name` (VARCHAR, UNIQUE, NOT NULL)
    *   `owner_id` (FK to `users.id`, NOT NULL)
    *   `subscription_id` (FK to `subscriptions.id`, NULLABLE)

*   **`users`**
    *   `phone_number` (VARCHAR, UNIQUE, NOT NULL)
    *   `password_hash` (VARCHAR, NOT NULL)

*   **`organization_users`** (Join table for many-to-many relationship)
    *   `user_id` (FK to `users.id`)
    *   `organization_id` (FK to `organizations.id`)
    *   `role` (VARCHAR, ENUM('owner', 'cashier'), NOT NULL)

*   **`plans`**
    *   `name` (VARCHAR, UNIQUE, NOT NULL, e.g., 'free', 'growth', 'pro')
    *   `price_monthly` (DECIMAL)
    *   `product_limit` (INTEGER)
    *   `user_limit` (INTEGER)
    *   `analytics_enabled` (BOOLEAN, NOT NULL)

*   **`subscriptions`**
    *   `organization_id` (FK to `organizations.id`, UNIQUE)
    *   `plan_id` (FK to `plans.id`)
    *   `status` (VARCHAR, ENUM('active', 'trial', 'canceled'), NOT NULL)
    *   `current_period_end` (TIMESTAMP)

*   **`products`**
    *   `organization_id` (FK to `organizations.id`, NOT NULL)
    *   `name` (VARCHAR, NOT NULL)
    *   `description` (TEXT)
    *   `category` (VARCHAR)
    *   `image_url` (VARCHAR)
    *   `vendor_id` (FK to `vendors.id`, NULLABLE)

*   **`variants`**
    *   `product_id` (FK to `products.id`, NOT NULL)
    *   `attributes` (JSONB, e.g., `{"Size": "L", "Color": "Red"}`)
    *   `sku` (VARCHAR, UNIQUE within an organization, NOT NULL)
    *   `purchase_price` (DECIMAL, NOT NULL, DEFAULT 0)
    *   `sale_price` (DECIMAL, NOT NULL)
    *   `quantity` (INTEGER, NOT NULL)
    *   `min_stock_level` (INTEGER)
    *   `unit_type` (VARCHAR, e.g., 'pcs', 'kg')

*   **`vendors`**
    *   `organization_id` (FK to `organizations.id`, NOT NULL)
    *   `name` (VARCHAR, NOT NULL)
    *   `contact_info` (TEXT)

*   **`sales`**
    *   `organization_id` (FK to `organizations.id`, NOT NULL)
    *   `user_id` (FK to `users.id`, NOT NULL)
    *   `total_amount` (DECIMAL, NOT NULL)
    *   `total_profit` (DECIMAL, NOT NULL)
    *   `payment_method` (VARCHAR, NOT NULL)
    *   `payment_proof_url` (VARCHAR, NULLABLE)
    *   `is_synced` (BOOLEAN, NOT NULL, DEFAULT TRUE) - *Used for offline sync tracking.*

*   **`sale_items`**
    *   `sale_id` (FK to `sales.id`, NOT NULL)
    *   `variant_id` (FK to `variants.id`, NOT NULL)
    *   `quantity` (INTEGER, NOT NULL)
    *   `price_at_sale` (DECIMAL, NOT NULL)
    *   `purchase_price_at_sale` (DECIMAL, NOT NULL)

#### **3.0 API Contract (OpenAPI 3.0 Summary)**

This is a summary of the API endpoints. The full OpenAPI/Swagger YAML file will be generated as a separate artifact. All endpoints are assumed to be prefixed with `/api/v1` and require JWT authentication.

*   **Authentication**
    *   `POST /auth/register` - Creates a new Organization and Owner User.
    *   `POST /auth/login` - Authenticates a user for a specific Organization, returns a JWT.

*   **Products & Variants**
    *   `GET /products` - List all products for the organization.
    *   `POST /products` - Create a new product (can include variants in the same request).
    *   `GET /products/{id}` - Get a single product with all its variants.
    *   `PUT /products/{id}` - Update a product.
    *   `DELETE /products/{id}` - Delete a product.
    *   `PUT /variants/{id}` - Update a single variant (e.g., its price or stock level).

*   **POS & Sales**
    *   `POST /sales` - The primary endpoint to process a new sale.
        *   **Request Body:** `{"payment_method": "Cash", "items": [{"variant_id": "...", "quantity": 2}]}`
        *   **Response:** The created `sale` object.
        *   **Logic:** This endpoint MUST be an atomic transaction in the database.
    *   `POST /sales/{id}/upload_proof` - Uploads a payment proof image for a sale.
    *   `GET /sales` - Get a paginated history of sales.
    *   `GET /sales/{id}` - Get details for a single sale, including its line items.

*   **Receipts**
    *   `GET /receipts/{sale_id}/pdf` - Generates and returns a PDF receipt for a given sale.

*   **Analytics**
    *   `GET /analytics/summary?start_date=...&end_date=...` - Returns key metrics (revenue, profit) for the given date range. Requires 'Owner' role and a non-free plan.

*   **Users** (Owner Role Only)
    *   `GET /users` - List all users in the organization.
    *   `POST /users/invite` - Invite a new user to the organization.
    *   `DELETE /users/{id}` - Remove a user from the organization.

#### **4.0 Offline Functionality Specification**

*   **4.1 Local Storage:** The Flutter application will use the Isar database to store a local copy of the product catalog and to queue sales made while offline.
*   **4.2 Offline Sales Queue:** When a sale is completed offline, a `sales` record will be created in the local Isar database with `is_synced` set to `FALSE`. The local `variants.quantity` will be immediately decremented.
*   **4.3 Syncing Mechanism:** A background service in the Flutter app will periodically check for internet connectivity.
    *   When online, it will attempt to `POST` each unsynced sale from the local queue to the backend `/sales` endpoint.
    *   Upon a successful `201` response from the server, the local sale record's `is_synced` flag is set to `TRUE`.
    *   The service should handle potential conflicts (e.g., if another device sold the last item while this one was offline) by flagging the sale for manual review.
    *   The service should also periodically fetch the latest product catalog from the backend to keep the local copy fresh.