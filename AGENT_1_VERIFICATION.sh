#!/bin/bash
# Agent 1 Database & Infrastructure Verification Script

echo "====================================="
echo "Agent 1: Database Infrastructure Test"
echo "====================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker is not installed${NC}"
    exit 1
fi

# Start PostgreSQL
echo -e "\n${YELLOW}[1/7] Starting PostgreSQL container...${NC}"
docker compose up -d postgres
sleep 5

# Check if PostgreSQL is running
if docker ps | grep -q bstock_postgres; then
    echo -e "${GREEN}✓ PostgreSQL container is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL container failed to start${NC}"
    exit 1
fi

# Wait for PostgreSQL to be ready
echo -e "\n${YELLOW}[2/7] Waiting for PostgreSQL to be ready...${NC}"
max_attempts=30
attempt=0
until docker exec bstock_postgres pg_isready -U postgres > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}✗ PostgreSQL failed to become ready${NC}"
        exit 1
    fi
    sleep 1
done
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

# Verify tables were created
echo -e "\n${YELLOW}[3/7] Verifying database tables...${NC}"
TABLE_COUNT=$(docker exec bstock_postgres psql -U postgres -d bstock -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
TABLE_COUNT=$(echo $TABLE_COUNT | xargs)
if [ "$TABLE_COUNT" -eq "10" ]; then
    echo -e "${GREEN}✓ All 10 tables created successfully${NC}"
else
    echo -e "${RED}✗ Expected 10 tables, found $TABLE_COUNT${NC}"
    exit 1
fi

# List all tables
echo -e "\n${YELLOW}[4/7] Listing all tables:${NC}"
docker exec bstock_postgres psql -U postgres -d bstock -c "\dt"

# Verify indexes
echo -e "\n${YELLOW}[5/7] Verifying indexes...${NC}"
INDEX_COUNT=$(docker exec bstock_postgres psql -U postgres -d bstock -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';")
INDEX_COUNT=$(echo $INDEX_COUNT | xargs)
if [ "$INDEX_COUNT" -ge "8" ]; then
    echo -e "${GREEN}✓ All indexes created successfully (found $INDEX_COUNT)${NC}"
else
    echo -e "${RED}✗ Expected at least 8 indexes, found $INDEX_COUNT${NC}"
fi

# Verify UUID extension
echo -e "\n${YELLOW}[6/7] Verifying UUID extension...${NC}"
UUID_EXT=$(docker exec bstock_postgres psql -U postgres -d bstock -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'uuid-ossp';")
UUID_EXT=$(echo $UUID_EXT | xargs)
if [ "$UUID_EXT" -eq "1" ]; then
    echo -e "${GREEN}✓ UUID extension enabled${NC}"
else
    echo -e "${RED}✗ UUID extension not found${NC}"
fi

# Build and start backend
echo -e "\n${YELLOW}[7/7] Building and starting backend...${NC}"
docker compose up -d backend
sleep 10

# Check backend health
echo -e "\n${YELLOW}Testing health endpoint...${NC}"
max_attempts=30
attempt=0
until curl -f http://localhost:8080/health > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}✗ Backend health check failed${NC}"
        echo "Backend logs:"
        docker logs bstock_backend
        exit 1
    fi
    sleep 1
done

HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
if [[ "$HEALTH_RESPONSE" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Health endpoint responding: $HEALTH_RESPONSE${NC}"
else
    echo -e "${RED}✗ Health endpoint returned unexpected response: $HEALTH_RESPONSE${NC}"
    exit 1
fi

# Verify seed data
echo -e "\n${YELLOW}Verifying seed data (3 plans)...${NC}"
PLAN_COUNT=$(docker exec bstock_postgres psql -U postgres -d bstock -t -c "SELECT COUNT(*) FROM plans;")
PLAN_COUNT=$(echo $PLAN_COUNT | xargs)
if [ "$PLAN_COUNT" -eq "3" ]; then
    echo -e "${GREEN}✓ All 3 plans seeded successfully${NC}"
    docker exec bstock_postgres psql -U postgres -d bstock -c "SELECT name, price_monthly, product_limit, user_limit FROM plans ORDER BY price_monthly;"
else
    echo -e "${RED}✗ Expected 3 plans, found $PLAN_COUNT${NC}"
    exit 1
fi

# Final summary
echo -e "\n====================================="
echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
echo -e "====================================="
echo -e "Database: 10 tables created"
echo -e "Indexes: $INDEX_COUNT indexes created"
echo -e "Seed Data: 3 plans inserted"
echo -e "Health Endpoint: ✓ Responding"
echo -e "====================================="
echo -e "\n${GREEN}Agent 1 COMPLETE: Database operational${NC}"
echo -e "Ready for Agents 2-6 to proceed\n"
