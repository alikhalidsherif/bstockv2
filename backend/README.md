# Bstock Backend

Go-based backend API for the Bstock inventory management system.

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Go 1.21+ (for local development)

### Start with Docker
```bash
# From project root
docker compose up -d

# View logs
docker compose logs -f backend

# Stop services
docker compose down
```

### Local Development

1. Start PostgreSQL:
```bash
docker compose up -d postgres
```

2. Set environment variables:
```bash
cp .env.example .env
```

3. Run the server:
```bash
go run cmd/server/main.go
```

## API Endpoints

### Health Check
```bash
GET /health
```

Response:
```json
{
  "status": "ok"
}
```

## Database

### Schema
- **10 tables** for multi-tenant inventory management
- **UUID primary keys** for all entities
- **Row-Level Security** enabled for multi-tenancy
- **8 indexes** for query optimization

### Tables
1. `organizations` - Tenant root
2. `users` - Authentication
3. `organization_users` - User-org relationships
4. `plans` - Subscription tiers
5. `subscriptions` - Active subscriptions
6. `vendors` - Suppliers
7. `products` - Product catalog
8. `variants` - SKU-level inventory
9. `sales` - Transactions
10. `sale_items` - Transaction line items

### Seed Data
Three subscription plans are automatically seeded:
- **Free**: $0/month, 15 products, 2 users
- **Growth**: $299.99/month, 500 products, 10 users
- **Pro**: $999.99/month, unlimited

## Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go          # Application entry point
├── database/
│   ├── connection.go        # Database connection
│   ├── schema.sql           # PostgreSQL schema
│   ├── rls_policies.sql     # Security policies
│   └── seed.go              # Seed data
├── models/
│   ├── base.go              # Base GORM model
│   └── plan.go              # Plan model
├── Dockerfile               # Container definition
├── go.mod                   # Go dependencies
└── .env.example             # Environment template
```

## Environment Variables

```env
DB_HOST=localhost
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=bstock
DB_PORT=5432
JWT_SECRET=your-secret-key
PORT=8080
```

## Testing

Run the automated verification:
```bash
cd ..
./AGENT_1_VERIFICATION.sh
```

## Dependencies

- **Gin** - HTTP web framework
- **GORM** - ORM with PostgreSQL driver
- **UUID** - UUID generation
- **JWT** - Authentication tokens
- **bcrypt** - Password hashing

## Next Steps

See `AGENT_1_COMPLETION_REPORT.md` for full documentation and handoff to other agents.
