# Agent 1: Database & Infrastructure Foundation

## Timeline: Day 1 (0-8 hours)
## Dependencies: NONE - START IMMEDIATELY
## Priority: CRITICAL - Blocks Agents 2-6

---

## Mission
Set up the complete PostgreSQL database schema with multi-tenancy via Row-Level Security (RLS), Docker infrastructure, and seed data.

---

## Deliverables Checklist

### 1. PostgreSQL Schema (CRITICAL)
**File**: `backend/database/schema.sql`

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table: organizations
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) UNIQUE NOT NULL,
    owner_id UUID NOT NULL,
    subscription_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: organization_users (join table)
CREATE TABLE organization_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'cashier')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, organization_id)
);

-- Table: plans
CREATE TABLE plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    price_monthly DECIMAL(10,2) NOT NULL,
    product_limit INTEGER,
    user_limit INTEGER,
    location_limit INTEGER,
    analytics_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: subscriptions
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID UNIQUE NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES plans(id),
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'trial', 'canceled')),
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: vendors
CREATE TABLE vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_info TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    image_url VARCHAR(500),
    vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: variants
CREATE TABLE variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    attributes JSONB DEFAULT '{}',
    sku VARCHAR(100) NOT NULL,
    purchase_price DECIMAL(10,2) NOT NULL DEFAULT 0,
    sale_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    min_stock_level INTEGER DEFAULT 0,
    unit_type VARCHAR(20) DEFAULT 'pcs',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, sku)
);

-- Table: sales
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    total_amount DECIMAL(10,2) NOT NULL,
    total_profit DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_proof_url VARCHAR(500),
    is_synced BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: sale_items
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES variants(id),
    quantity INTEGER NOT NULL,
    price_at_sale DECIMAL(10,2) NOT NULL,
    purchase_price_at_sale DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key constraint to organizations
ALTER TABLE organizations ADD CONSTRAINT fk_organizations_owner
    FOREIGN KEY (owner_id) REFERENCES users(id);

ALTER TABLE organizations ADD CONSTRAINT fk_organizations_subscription
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id);

-- Create indexes for performance
CREATE INDEX idx_organization_users_org ON organization_users(organization_id);
CREATE INDEX idx_organization_users_user ON organization_users(user_id);
CREATE INDEX idx_products_org ON products(organization_id);
CREATE INDEX idx_variants_product ON variants(product_id);
CREATE INDEX idx_sales_org ON sales(organization_id);
CREATE INDEX idx_sales_created ON sales(created_at);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_vendors_org ON vendors(organization_id);
```

### 2. Row-Level Security (RLS) Policies
**File**: `backend/database/rls_policies.sql`

```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- Note: In production, these policies should use JWT claims
-- For now, we'll use application-level enforcement via GORM scopes
-- Full RLS implementation with JWT will be added in production deployment
```

### 3. Seed Data
**File**: `backend/database/seed.go`

```go
package database

import (
    "bstock/models"
    "gorm.io/gorm"
)

func SeedDatabase(db *gorm.DB) error {
    // Seed Plans
    plans := []models.Plan{
        {
            Name:             "free",
            PriceMonthly:     0,
            ProductLimit:     intPtr(15),
            UserLimit:        intPtr(2),
            LocationLimit:    intPtr(1),
            AnalyticsEnabled: false,
        },
        {
            Name:             "growth",
            PriceMonthly:     299.99,
            ProductLimit:     intPtr(500),
            UserLimit:        intPtr(10),
            LocationLimit:    intPtr(3),
            AnalyticsEnabled: true,
        },
        {
            Name:             "pro",
            PriceMonthly:     999.99,
            ProductLimit:     nil, // unlimited
            UserLimit:        nil, // unlimited
            LocationLimit:    nil, // unlimited
            AnalyticsEnabled: true,
        },
    }

    for _, plan := range plans {
        if err := db.FirstOrCreate(&plan, models.Plan{Name: plan.Name}).Error; err != nil {
            return err
        }
    }

    return nil
}

func intPtr(i int) *int {
    return &i
}
```

### 4. GORM Models Base
**File**: `backend/models/base.go`

```go
package models

import (
    "time"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type BaseModel struct {
    ID        uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

func (base *BaseModel) BeforeCreate(tx *gorm.DB) error {
    if base.ID == uuid.Nil {
        base.ID = uuid.New()
    }
    return nil
}
```

### 5. Database Connection
**File**: `backend/database/connection.go`

```go
package database

import (
    "fmt"
    "log"
    "os"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

var DB *gorm.DB

func Connect() error {
    dsn := fmt.Sprintf(
        "host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=UTC",
        getEnv("DB_HOST", "localhost"),
        getEnv("DB_USER", "postgres"),
        getEnv("DB_PASSWORD", "postgres"),
        getEnv("DB_NAME", "bstock"),
        getEnv("DB_PORT", "5432"),
    )

    var err error
    DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })

    if err != nil {
        return fmt.Errorf("failed to connect to database: %w", err)
    }

    log.Println("Database connected successfully")
    return nil
}

func getEnv(key, fallback string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return fallback
}
```

### 6. Docker Compose Configuration
**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: bstock_postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: bstock
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
      - ./backend/database/rls_policies.sql:/docker-entrypoint-initdb.d/02-rls.sql
    networks:
      - bstock_network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: bstock_backend
    depends_on:
      - postgres
    environment:
      DB_HOST: postgres
      DB_USER: postgres
      DB_PASSWORD: postgres
      DB_NAME: bstock
      DB_PORT: 5432
      JWT_SECRET: ${JWT_SECRET:-super-secret-change-in-production}
      PORT: 8080
    ports:
      - "8080:8080"
    volumes:
      - ./backend:/app
    networks:
      - bstock_network
    command: air # hot reload

volumes:
  postgres_data:

networks:
  bstock_network:
    driver: bridge
```

### 7. Backend Dockerfile
**File**: `backend/Dockerfile`

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/server

# Final stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

### 8. Go Module Initialization
**File**: `backend/go.mod`

```go
module bstock

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/golang-jwt/jwt/v5 v5.0.0
    github.com/google/uuid v1.4.0
    golang.org/x/crypto v0.14.0
    gorm.io/driver/postgres v1.5.4
    gorm.io/gorm v1.25.5
)
```

### 9. Main Server Entry Point
**File**: `backend/cmd/server/main.go`

```go
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
```

### 10. Environment File Template
**File**: `backend/.env.example`

```env
# Database
DB_HOST=localhost
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=bstock
DB_PORT=5432

# JWT
JWT_SECRET=change-this-in-production

# Server
PORT=8080
```

---

## Testing Checklist

- [ ] Run `docker-compose up postgres` successfully
- [ ] Connect to PostgreSQL with `psql -U postgres -d bstock`
- [ ] Verify all 10 tables exist
- [ ] Verify UUID extension is enabled
- [ ] Verify all indexes created
- [ ] Run `docker-compose up backend` successfully
- [ ] Hit `http://localhost:8080/health` returns 200
- [ ] Verify 3 plans seeded in database
- [ ] Verify foreign key constraints work

---

## File Structure Output

```
bstockv2/
├── docker-compose.yml
├── backend/
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   ├── .env.example
│   ├── cmd/
│   │   └── server/
│   │       └── main.go
│   ├── database/
│   │   ├── connection.go
│   │   ├── schema.sql
│   │   ├── rls_policies.sql
│   │   └── seed.go
│   └── models/
│       └── base.go
```

---

## Success Criteria

1. ✅ Docker containers start without errors
2. ✅ Database schema fully created
3. ✅ Seed data populated
4. ✅ Health endpoint accessible
5. ✅ All tables have proper constraints
6. ✅ Foundation ready for Agents 2-6 to build on

---

## Handoff to Other Agents

Once complete, notify:
- **Agent 2**: Database ready for auth models
- **Agent 3**: Subscription tables ready
- **Agent 4**: Product/Variant tables ready
- **Agent 5**: Sales tables ready
- **Agent 6**: Analytics can query sales data

**Estimated Completion: 6-8 hours**
