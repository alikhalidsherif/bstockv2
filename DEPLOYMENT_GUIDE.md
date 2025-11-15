# 🚀 Bstock Deployment Guide - Home Server with Portainer

## Your Infrastructure
- ✅ Docker + Portainer (Web UI)
- ✅ Nginx Proxy Manager (Reverse proxy)
- ✅ Cloudflared (Cloudflare Tunnel)
- ✅ Domain: ashreef.com

---

## 📋 Pre-Deployment Checklist

### 1. Domain Setup in Cloudflare
- [ ] Login to Cloudflare dashboard
- [ ] Navigate to ashreef.com DNS settings
- [ ] Create A records (will be managed by Cloudflared tunnel)

### 2. Required Subdomains
You'll need these subdomains:
- `api.ashreef.com` - Backend API
- `bstock.ashreef.com` - Flutter Web App (optional)

---

## 🔧 STEP 1: Prepare the Repository

### Clone/Pull Latest Code
```bash
# On your home server
cd /opt/docker  # or wherever you keep your docker projects
git clone https://github.com/alikhalidsherif/bstockv2.git
cd bstockv2
git checkout claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4
```

---

## 🐳 STEP 2: Configure Environment Variables

### Create Production Environment File
```bash
cd /opt/docker/bstockv2
nano .env.production
```

### Paste this configuration:
```env
# Database Configuration
POSTGRES_USER=bstock_admin
POSTGRES_PASSWORD=CHANGE_THIS_STRONG_PASSWORD_123!
POSTGRES_DB=bstock_production
DB_HOST=postgres
DB_PORT=5432

# Backend Configuration
JWT_SECRET=CHANGE_THIS_TO_A_VERY_LONG_RANDOM_STRING_AT_LEAST_32_CHARS
PORT=8080
GIN_MODE=release

# Domain Configuration
API_DOMAIN=api.ashreef.com
FRONTEND_DOMAIN=bstock.ashreef.com

# CORS Configuration
ALLOWED_ORIGINS=https://bstock.ashreef.com,http://localhost:3000

# Database Connection String
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:${DB_PORT}/${POSTGRES_DB}?sslmode=disable
```

**🔐 SECURITY: Change these immediately:**
1. `POSTGRES_PASSWORD` - Use a strong 20+ character password
2. `JWT_SECRET` - Generate with: `openssl rand -base64 48`

---

## 🐳 STEP 3: Deploy via Portainer

### Option A: Using Portainer Stacks (RECOMMENDED)

1. **Login to Portainer** (usually at `http://your-server-ip:9000`)

2. **Navigate to Stacks** → **Add Stack**

3. **Stack Name:** `bstock-production`

4. **Web Editor:** Paste the production docker-compose.yml (see below)

5. **Environment Variables:**
   - Click "Add environment variable"
   - Add all variables from `.env.production`

6. **Deploy the Stack**

### Production Docker Compose (for Portainer)

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: bstock_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
      - ./backend/database/rls_policies.sql:/docker-entrypoint-initdb.d/02-rls.sql
    networks:
      - bstock_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: bstock_backend
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DB_HOST: postgres
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB}
      DB_PORT: 5432
      JWT_SECRET: ${JWT_SECRET}
      PORT: 8080
      GIN_MODE: release
    expose:
      - "8080"
    volumes:
      - ./uploads:/app/uploads
    networks:
      - bstock_network
      - proxy  # For Nginx Proxy Manager
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
    driver: local

networks:
  bstock_network:
    driver: bridge
  proxy:
    external: true  # Connect to Nginx Proxy Manager network
```

### Option B: Using Docker Compose CLI

```bash
cd /opt/docker/bstockv2
docker-compose -f docker-compose.production.yml --env-file .env.production up -d
```

---

## 🌐 STEP 4: Configure Nginx Proxy Manager

### 1. Login to Nginx Proxy Manager
Usually at: `http://your-server-ip:81`

### 2. Add Proxy Host for Backend API

**Proxy Hosts → Add Proxy Host**

**Details Tab:**
- **Domain Names:** `api.ashreef.com`
- **Scheme:** `http`
- **Forward Hostname/IP:** `bstock_backend` (or container IP)
- **Forward Port:** `8080`
- **Cache Assets:** ✅ Enabled
- **Block Common Exploits:** ✅ Enabled
- **Websockets Support:** ❌ Disabled

**SSL Tab:**
- **SSL Certificate:** Request a New SSL Certificate
- **Force SSL:** ✅ Enabled
- **HTTP/2 Support:** ✅ Enabled
- **HSTS Enabled:** ✅ Enabled
- **Email:** your-email@example.com
- **Agree to Let's Encrypt ToS:** ✅

**Advanced Tab:**
```nginx
# CORS Headers for API
add_header 'Access-Control-Allow-Origin' 'https://bstock.ashreef.com' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;

# Handle preflight requests
if ($request_method = 'OPTIONS') {
    return 204;
}

# API rate limiting (optional)
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/m;
limit_req zone=api_limit burst=10 nodelay;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

**Save** and test: `https://api.ashreef.com/health`

### 3. Add Proxy Host for Flutter Web (Optional)

If deploying Flutter web version:

**Details Tab:**
- **Domain Names:** `bstock.ashreef.com`
- **Scheme:** `http`
- **Forward Hostname/IP:** `bstock_frontend`
- **Forward Port:** `80`

**SSL Tab:** Same as above

---

## ☁️ STEP 5: Configure Cloudflare Tunnel

### Option 1: Using Cloudflared CLI (Recommended)

```bash
# Install cloudflared (if not already installed)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create bstock-tunnel

# Configure tunnel
nano ~/.cloudflared/config.yml
```

**Cloudflared config.yml:**
```yaml
tunnel: bstock-tunnel
credentials-file: /root/.cloudflared/<TUNNEL-ID>.json

ingress:
  - hostname: api.ashreef.com
    service: http://nginx-proxy-manager:80
  - hostname: bstock.ashreef.com
    service: http://nginx-proxy-manager:80
  - service: http_status:404
```

```bash
# Route DNS
cloudflared tunnel route dns bstock-tunnel api.ashreef.com
cloudflared tunnel route dns bstock-tunnel bstock.ashreef.com

# Run tunnel
cloudflared tunnel run bstock-tunnel
```

### Option 2: Using Cloudflare Dashboard

1. Go to **Cloudflare Dashboard** → **Zero Trust** → **Tunnels**
2. **Create Tunnel** → Name: `bstock-tunnel`
3. **Install Connector** → Choose your OS and run the command
4. **Route Traffic:**
   - Public Hostname: `api.ashreef.com` → `http://nginx-proxy-manager:80`
   - Public Hostname: `bstock.ashreef.com` → `http://nginx-proxy-manager:80`

---

## 📱 STEP 6: Build Flutter App for Production

### Update API Configuration

**Edit:** `frontend/lib/config/app_config.dart`

```dart
class AppConfig {
  // Change this to your production API
  static const String apiBaseUrl = 'https://api.ashreef.com/api/v1';

  // Rest of config stays the same...
}
```

### Build for Web (Optional)
```bash
cd frontend
flutter build web --release --web-renderer html

# Deploy to web server or serve with nginx
# Output is in: build/web/
```

### Build Mobile Apps

**Android APK:**
```bash
cd frontend
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release

# AAB location: build/app/outputs/bundle/release/app-release.aab
```

**iOS (requires macOS):**
```bash
flutter build ios --release
```

---

## 🔐 STEP 7: Security Hardening

### 1. Change Default Passwords
```bash
# Generate strong JWT secret
openssl rand -base64 48

# Update .env.production with new values
```

### 2. Configure Firewall Rules
```bash
# Only allow traffic from Cloudflare IPs (optional)
# Get Cloudflare IP ranges: https://www.cloudflare.com/ips/

# Allow only necessary ports
ufw allow 80/tcp    # HTTP (for Let's Encrypt)
ufw allow 443/tcp   # HTTPS
ufw allow 22/tcp    # SSH (change default port recommended)
ufw enable
```

### 3. Setup Database Backups
```bash
# Create backup script
nano /opt/scripts/backup-bstock.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/bstock"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker exec bstock_postgres pg_dump -U bstock_admin bstock_production > \
  $BACKUP_DIR/bstock_db_$DATE.sql

# Backup uploads
tar -czf $BACKUP_DIR/bstock_uploads_$DATE.tar.gz ./uploads

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
```

```bash
chmod +x /opt/scripts/backup-bstock.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add: 0 2 * * * /opt/scripts/backup-bstock.sh
```

---

## 🧪 STEP 8: Testing & Verification

### 1. Check Container Health
```bash
# Via Portainer: Containers → Check status (all should be green/healthy)

# Via CLI:
docker ps
docker logs bstock_backend
docker logs bstock_postgres
```

### 2. Test API Endpoints

**Health Check:**
```bash
curl https://api.ashreef.com/health
# Expected: {"status":"ok"}
```

**Register Test User:**
```bash
curl -X POST https://api.ashreef.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "testpass123"
  }'
```

**Login:**
```bash
curl -X POST https://api.ashreef.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "testpass123"
  }'
```

### 3. Test Flutter App

**On Web:**
- Navigate to: `https://bstock.ashreef.com`

**On Mobile:**
- Install APK on Android device
- Open app and test registration/login

---

## 📊 STEP 9: Monitoring & Maintenance

### Setup Watchtower (Auto-Updates)

Add to your Portainer stack or docker-compose:

```yaml
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400  # Check daily
      - WATCHTOWER_LABEL_ENABLE=true
    networks:
      - bstock_network
```

### View Logs via Portainer
1. **Portainer** → **Containers**
2. Click on container name
3. **Logs** tab → Real-time logs

### Database Monitoring
```bash
# Connect to PostgreSQL
docker exec -it bstock_postgres psql -U bstock_admin -d bstock_production

# Check tables
\dt

# Check record counts
SELECT COUNT(*) FROM organizations;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM sales;
```

---

## 🚨 Troubleshooting

### Issue: Backend won't start
```bash
# Check logs
docker logs bstock_backend

# Common issues:
# 1. Database not ready → Wait for postgres healthcheck
# 2. Wrong credentials → Check .env.production
# 3. Port conflict → Check if 8080 is available
```

### Issue: Can't connect to API from Flutter app
```bash
# 1. Check CORS headers in Nginx Proxy Manager
# 2. Verify SSL certificate is valid
# 3. Test API directly: curl https://api.ashreef.com/health
# 4. Check Flutter app_config.dart has correct API URL
```

### Issue: Database connection errors
```bash
# Check database is running
docker exec bstock_postgres pg_isready -U bstock_admin

# Test connection
docker exec -it bstock_postgres psql -U bstock_admin -d bstock_production

# Verify environment variables
docker exec bstock_backend env | grep DB_
```

### Issue: SSL Certificate Problems
```bash
# Regenerate certificate in Nginx Proxy Manager
# 1. Delete existing certificate
# 2. Request new one
# 3. Ensure ports 80/443 are open
# 4. Check Cloudflare DNS is correct
```

---

## 📋 Post-Deployment Checklist

- [ ] All containers running (green in Portainer)
- [ ] API health endpoint responds: `https://api.ashreef.com/health`
- [ ] SSL certificates valid and auto-renewing
- [ ] Can register new user via API
- [ ] Can login via Flutter app
- [ ] Database backups scheduled
- [ ] Monitoring/logging setup
- [ ] Firewall rules configured
- [ ] Strong passwords set for DB and JWT
- [ ] CORS headers working
- [ ] Mobile app can connect to API

---

## 🔄 Updating the Application

### Update Backend Code
```bash
cd /opt/docker/bstockv2
git pull origin claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4

# Via Portainer:
# Stacks → bstock-production → Editor → Pull and redeploy

# Via CLI:
docker-compose -f docker-compose.production.yml up -d --build
```

### Update Flutter App
```bash
cd frontend
git pull
flutter build apk --release

# Distribute new APK to users
# Or publish to Play Store
```

---

## 📞 Support & Resources

### Useful Commands
```bash
# View all Bstock containers
docker ps -a | grep bstock

# Restart backend
docker restart bstock_backend

# View backend logs (last 100 lines)
docker logs --tail 100 bstock_backend

# Database shell
docker exec -it bstock_postgres psql -U bstock_admin -d bstock_production

# Check disk usage
docker system df
```

### Key URLs
- **API:** https://api.ashreef.com
- **Web App:** https://bstock.ashreef.com
- **Portainer:** http://your-server-ip:9000
- **Nginx Proxy Manager:** http://your-server-ip:81

---

## 🎉 Deployment Complete!

Your Bstock POS system is now running on:
- **API:** https://api.ashreef.com
- **Mobile App:** Download APK and install
- **Management:** via Portainer web interface

**Next Steps:**
1. Test registration and login
2. Create your first products
3. Make a test sale
4. Check analytics dashboard
5. Test offline mode

**Need help?** Check the troubleshooting section above or review the logs in Portainer.

---

**Deployment Status: READY FOR PRODUCTION! 🚀**
