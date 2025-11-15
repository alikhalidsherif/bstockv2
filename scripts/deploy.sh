#!/bin/bash

# Bstock Deployment Script
# Usage: ./scripts/deploy.sh

set -e  # Exit on error

echo "🚀 Starting Bstock Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env.production exists
if [ ! -f .env.production ]; then
    echo -e "${RED}❌ Error: .env.production not found${NC}"
    echo "Please create .env.production from .env.production.example"
    exit 1
fi

echo -e "${GREEN}✅ Environment file found${NC}"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Not running as root. You may need sudo for Docker commands.${NC}"
fi

# Pull latest code
echo "📥 Pulling latest code from git..."
git pull origin claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.production.yml down

# Pull latest images
echo "🐳 Pulling latest Docker images..."
docker-compose -f docker-compose.production.yml pull

# Build backend
echo "🔨 Building backend image..."
docker-compose -f docker-compose.production.yml build backend

# Start services
echo "🚀 Starting services..."
docker-compose -f docker-compose.production.yml --env-file .env.production up -d

# Wait for health checks
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check backend health
echo "🏥 Checking backend health..."
for i in {1..30}; do
    if docker exec bstock_backend wget --quiet --tries=1 --spider http://localhost:8080/health 2>/dev/null; then
        echo -e "${GREEN}✅ Backend is healthy!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Backend health check failed${NC}"
        echo "Check logs with: docker logs bstock_backend"
        exit 1
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Show running containers
echo ""
echo "📊 Running containers:"
docker-compose -f docker-compose.production.yml ps

# Show logs
echo ""
echo "📜 Recent backend logs:"
docker logs --tail 20 bstock_backend

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "🌐 Your API should be accessible at:"
echo "   https://api.ashreef.com/health"
echo ""
echo "📱 Next steps:"
echo "   1. Configure Nginx Proxy Manager"
echo "   2. Set up Cloudflare Tunnel"
echo "   3. Test API endpoints"
echo "   4. Deploy Flutter app"
echo ""
echo "📚 See DEPLOYMENT_GUIDE.md for detailed instructions"
