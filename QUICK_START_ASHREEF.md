# 🚀 Bstock Quick Start for ashreef.com

## Fastest Way to Deploy on Your Home Server

### Prerequisites
✅ Portainer running
✅ Nginx Proxy Manager running
✅ Cloudflared tunnel active
✅ Domain: ashreef.com configured in Cloudflare

---

## 📦 STEP 1: Clone Repository (2 minutes)

SSH into your home server:

```bash
cd /opt/docker
git clone https://github.com/alikhalidsherif/bstockv2.git
cd bstockv2
git checkout claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4
```

---

## 🔐 STEP 2: Create Environment File (3 minutes)

```bash
cp .env.production.example .env.production
nano .env.production
```

**Update these values:**
```env
POSTGRES_PASSWORD=YourSuperStrongPassword123!
JWT_SECRET=GenerateThisWithOpenssl48Chars
ALLOWED_ORIGINS=https://bstock.ashreef.com
```

**Generate JWT Secret:**
```bash
openssl rand -base64 48
```

Copy the output and paste it into `JWT_SECRET`

Save and exit (Ctrl+X, Y, Enter)

---

## 🐳 STEP 3: Deploy in Portainer (5 minutes)

### 3.1 Open Portainer
Go to: `http://your-server-ip:9000`

### 3.2 Create Stack
1. **Stacks** → **Add Stack**
2. **Name:** `bstock`
3. **Build method:** Upload → Upload `docker-compose.production.yml`
4. Or **Web editor** → Paste contents of `docker-compose.production.yml`

### 3.3 Add Environment Variables
Click **Add environment variable** and add each one from your `.env.production` file:

- `POSTGRES_USER` = `bstock_admin`
- `POSTGRES_PASSWORD` = (your password)
- `POSTGRES_DB` = `bstock_production`
- `JWT_SECRET` = (your generated secret)
- `ALLOWED_ORIGINS` = `https://bstock.ashreef.com`

### 3.4 Deploy
Click **Deploy the stack**

Wait 30 seconds for containers to start.

### 3.5 Verify
Check all containers show as "running" (green)

---

## 🌐 STEP 4: Configure Nginx Proxy Manager (5 minutes)

### 4.1 Open NPM
Go to: `http://your-server-ip:81`

### 4.2 Add Proxy Host
**Hosts** → **Proxy Hosts** → **Add Proxy Host**

**Details Tab:**
- Domain Names: `api.ashreef.com`
- Scheme: `http`
- Forward Hostname/IP: `bstock_backend`
- Forward Port: `8080`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL Tab:**
- ✅ Request a New SSL Certificate
- ✅ Force SSL
- ✅ HTTP/2 Support
- Email: your-email@example.com
- ✅ I Agree to Let's Encrypt ToS

**Advanced Tab:**
Paste this:
```nginx
# CORS
add_header 'Access-Control-Allow-Origin' '$http_origin' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;

# Security
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
```

Click **Save**

---

## ☁️ STEP 5: Configure Cloudflare Tunnel (5 minutes)

### Option A: Cloudflare Dashboard (Easiest)

1. Go to **Cloudflare Dashboard** → **Zero Trust** → **Access** → **Tunnels**
2. Select your existing tunnel or **Create a tunnel**
3. **Public Hostnames** → **Add a public hostname**
   - Subdomain: `api`
   - Domain: `ashreef.com`
   - Service: `http://nginx-proxy-manager:81`
4. **Save**

### Option B: CLI (If you prefer)

```bash
cloudflared tunnel route dns your-tunnel-name api.ashreef.com
```

---

## ✅ STEP 6: Test Everything (2 minutes)

### Test API Health
Open in browser or run:
```bash
curl https://api.ashreef.com/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "bstock-api",
  "version": "1.0.0"
}
```

### Test Registration
```bash
curl -X POST https://api.ashreef.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "My Test Shop",
    "phone_number": "+251911234567",
    "password": "testpass123"
  }'
```

You should get a JSON response with a token!

---

## 📱 STEP 7: Build and Install Mobile App (10 minutes)

### On your development machine:

```bash
cd bstockv2/frontend

# Update for production (already done - API auto-switches)

# Build APK
flutter build apk --release

# APK is at: build/app/outputs/flutter-apk/app-release.apk
```

### Transfer APK to your phone:
- Via USB
- Via email
- Via Dropbox/Drive
- Or `adb install build/app/outputs/flutter-apk/app-release.apk`

### Install and Test
1. Open Bstock app
2. Tap "New shop? Register here"
3. Enter shop name, phone, password
4. You should be logged in!

---

## 🎯 That's It!

**Total Time: ~30 minutes**

Your Bstock POS system is now live at:
- **API:** https://api.ashreef.com
- **Mobile App:** Installed on your phone

---

## 🔧 Quick Troubleshooting

### Issue: "Can't connect to API"
**Fix:**
1. Check Portainer → all containers running?
2. Check NPM → proxy host exists?
3. Check Cloudflare Tunnel → hostname configured?
4. Test: `curl https://api.ashreef.com/health`

### Issue: "Database error"
**Fix:**
```bash
# Check database logs
docker logs bstock_postgres

# Reset database (CAUTION: deletes all data)
docker-compose -f docker-compose.production.yml down -v
docker-compose -f docker-compose.production.yml up -d
```

### Issue: "SSL certificate error"
**Fix:**
- Wait 2 minutes for Let's Encrypt
- Check ports 80 and 443 are open
- Verify DNS points to your tunnel

### Issue: "App crashes on startup"
**Fix:**
- Make sure you built with `--release` flag
- Check app can reach `https://api.ashreef.com/health` in browser first
- Check Flutter logs: `flutter logs`

---

## 📊 Monitoring

### View Logs (Portainer)
1. **Containers** → Click container name
2. **Logs** tab
3. Real-time logs appear

### View Logs (CLI)
```bash
# Backend logs
docker logs -f bstock_backend

# Database logs
docker logs -f bstock_postgres
```

### Database Access
```bash
docker exec -it bstock_postgres psql -U bstock_admin -d bstock_production

# View tables
\dt

# View organizations
SELECT * FROM organizations;

# Exit
\q
```

---

## 🔄 Updates

### Update Backend Code
```bash
cd /opt/docker/bstockv2
git pull
docker-compose -f docker-compose.production.yml up -d --build
```

### Update Mobile App
```bash
cd frontend
git pull
flutter build apk --release
# Distribute new APK
```

---

## 📞 Need Help?

Check the full deployment guide: `DEPLOYMENT_GUIDE.md`

---

**Congratulations! Your Bstock POS is running! 🎉**
