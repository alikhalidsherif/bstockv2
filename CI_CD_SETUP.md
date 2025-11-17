# CI/CD Setup Guide for Bstock

## Overview

Your CI/CD pipeline is configured to:
- ✅ **Auto-deploy** when you push to your branch
- ✅ **Run tests** on pull requests
- ✅ **Build on your home server** (no external dependencies)
- ✅ **Zero-downtime** deployments

---

## 🏠 Option 1: Self-Hosted Runner (RECOMMENDED)

### Why Self-Hosted?
- Builds directly on your server
- No need for Docker registry
- Faster deployments (no image push/pull)
- No rate limits
- Works with your existing Portainer + Nginx Proxy Manager setup
- Containers connect to your existing `proxy` network
- Free (no GitHub minutes used)

### Setup Steps

#### Step 1: Install GitHub Actions Runner on Your Server

SSH into your server:

```bash
# Create a directory for the runner
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the latest runner package (check for latest version at GitHub)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure the runner
./config.sh --url https://github.com/alikhalidsherif/bstockv2 --token <YOUR_TOKEN>
```

**Get your registration token:**
1. Go to: https://github.com/alikhalidsherif/bstockv2/settings/actions/runners/new
2. Copy the token shown in step 2
3. Use it in the `./config.sh` command above

**When prompted, answer:**
- Runner group: `Default` (press Enter)
- Runner name: `bstock-server` (or any name you prefer)
- Work folder: `_work` (press Enter for default)
- Labels: `self-hosted,Linux,X64` (press Enter for defaults)

#### Step 2: Install Runner as a System Service

```bash
# Install the service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status

# Enable auto-start on boot
sudo systemctl enable actions.runner.*
```

#### Step 3: Verify Runner is Connected

1. Go to: https://github.com/alikhalidsherif/bstockv2/settings/actions/runners
2. You should see your runner with a green "Idle" status

#### Step 4: Add GitHub Repository Secrets

Go to: https://github.com/alikhalidsherif/bstockv2/settings/secrets/actions

Click **New repository secret** and add each of these:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `POSTGRES_USER` | Your database user | `bstock_admin` |
| `POSTGRES_PASSWORD` | Your strong database password | `YourSuperSecurePass123!` |
| `POSTGRES_DB` | Database name | `bstock_production` |
| `JWT_SECRET` | Your JWT secret (48+ chars) | Generate with: `openssl rand -base64 48` |
| `ALLOWED_ORIGINS` | Frontend URLs | `https://bstock.ashreef.com` |

#### Step 5: Configure Nginx Proxy Manager

The deployment creates containers with specific names that must match your Nginx Proxy Manager configuration:

**Backend Container:** `bstock-backend`
- In Nginx Proxy Manager, create a Proxy Host for `api.ashreef.com`
- Set Forward Hostname/IP to: `bstock-backend`
- Set Forward Port to: `8080`
- Enable SSL with Let's Encrypt
- The container connects to your existing `proxy` network automatically

**Database Container:** `bstock-postgres`
- Internal use only (not exposed via Nginx Proxy Manager)
- Accessible to backend via hostname `bstock-postgres:5432`

#### Step 6: Test Your CI/CD Pipeline

```bash
# On your development machine
cd /path/to/bstockv2

# Make a small change (like updating a comment)
echo "# CI/CD test" >> README.md

# Commit and push
git add .
git commit -m "Test: CI/CD deployment pipeline"
git push origin claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4
```

#### Step 7: Watch the Deployment

1. Go to: https://github.com/alikhalidsherif/bstockv2/actions
2. Click on the running workflow
3. Watch the deployment progress in real-time
4. Check your server at: `https://api.ashreef.com/health`

**The deployment will:**
1. Checkout latest code from your branch
2. Create .env file from GitHub Secrets
3. Setup PostgreSQL container (bstock-postgres) if needed
4. Build backend Docker image tagged with commit SHA
5. Stop and remove old backend container
6. Start new backend container (bstock-backend) on proxy network
7. Wait for health checks (30 second timeout)
8. Clean up .env file and old images
9. Show deployment status and logs

**Important:** Container name `bstock-backend` MUST match your Nginx Proxy Manager Forward Hostname/IP configuration.

---

## ☁️ Option 2: GitHub Container Registry (Alternative)

If you can't or don't want to run a self-hosted runner, use this option.

### How it Works
1. GitHub Actions builds Docker image
2. Pushes to GitHub Container Registry (GHCR)
3. Watchtower on your server auto-pulls and updates

### Setup Steps

#### Step 1: Enable the GHCR Workflow

```bash
cd /path/to/bstockv2
mv .github/workflows/build-ghcr.yml.example .github/workflows/build-ghcr.yml
git add .github/workflows/build-ghcr.yml
git commit -m "Enable GHCR workflow"
git push
```

#### Step 2: Update docker-compose.production.yml

Change the backend image to pull from GHCR:

```yaml
services:
  backend:
    image: ghcr.io/alikhalidsherif/bstockv2:latest  # Use pre-built image
    # Remove the 'build' section
    container_name: bstock_backend
    restart: unless-stopped
    # ... rest of config stays the same
```

#### Step 3: Configure Watchtower

Watchtower is already in your docker-compose.production.yml and will:
- Check for new images every 24 hours
- Pull and restart containers automatically
- Clean up old images

To force an immediate update:
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once \
  bstock_backend
```

---

## 📊 What Happens on Each Push

### Automatic Workflow Triggers

**When you push to main/your branch:**
```
1. GitHub detects push
2. Workflow starts (`.github/workflows/deploy.yml`)
3. Runner pulls latest code
4. Builds Docker images
5. Stops old containers
6. Starts new containers
7. Runs health checks
8. Notifies you of success/failure
```

**On Pull Requests:**
```
1. Runs tests (`.github/workflows/test.yml`)
2. Builds backend
3. Builds Flutter app
4. Runs linters
5. Reports status to PR
```

---

## 🔍 Monitoring Your Deployments

### View Deployment Logs

**In GitHub:**
https://github.com/alikhalidsherif/bstockv2/actions

**On Your Server:**
```bash
# View runner logs
sudo journalctl -u actions.runner.* -f

# View backend container logs
docker logs -f bstock-backend

# View PostgreSQL container logs
docker logs -f bstock-postgres
```

### Check Deployment Status

```bash
# Check if containers are running
docker ps | grep bstock

# Check backend health
curl https://api.ashreef.com/health

# View recent backend logs
docker logs --tail 50 bstock-backend
```

---

## 🚨 Troubleshooting

### Issue: Runner Not Connecting

**Check runner status:**
```bash
cd ~/actions-runner
sudo ./svc.sh status
```

**Restart runner:**
```bash
sudo ./svc.sh stop
sudo ./svc.sh start
```

**Check logs:**
```bash
sudo journalctl -u actions.runner.* -n 50
```

### Issue: Deployment Fails

**Check workflow logs:**
1. Go to GitHub Actions
2. Click on failed workflow
3. Check which step failed
4. Review error messages

**Common fixes:**
- **Build fails:** Check if Go dependencies changed
- **Health check fails:** Check database connection
- **Port conflict:** Ensure ports 8080 is available
- **Permission denied:** Runner needs Docker access

**Give runner Docker access:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: Secrets Not Working

**Verify secrets are set:**
1. Go to: https://github.com/alikhalidsherif/bstockv2/settings/secrets/actions
2. Ensure all 5 secrets are there
3. Update any that are incorrect

**Re-run workflow:**
1. Go to failed workflow
2. Click "Re-run all jobs"

---

## 🔐 Security Best Practices

### Protect Your Secrets
- ✅ Never commit `.env.production` to git
- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate JWT secret periodically
- ✅ Use strong database passwords

### Secure Your Runner
```bash
# Update runner regularly
cd ~/actions-runner
sudo ./svc.sh stop
./config.sh remove
# Download latest runner and reconfigure
sudo ./svc.sh install
sudo ./svc.sh start
```

### Limit Runner Permissions
- Only install runner in a dedicated directory
- Don't run runner as root
- Use Docker user namespacing if possible

---

## 📈 Advanced Configuration

### Deploy Only on Main Branch

Edit `.github/workflows/deploy.yml`:
```yaml
on:
  push:
    branches:
      - main  # Remove other branches
```

### Add Slack/Discord Notifications

Add to end of deploy.yml:
```yaml
      - name: 🔔 Send Slack notification
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Run Database Migrations

Already handled! The backend automatically runs migrations on startup.

### Rollback Deployment

```bash
# Find the previous image
docker images | grep bstock-backend-image

# Stop current container
docker stop bstock-backend
docker rm bstock-backend

# Run previous image version
docker run -d \
  --name bstock-backend \
  --restart unless-stopped \
  --network proxy \
  --env-file /path/to/.env \
  -v /path/to/uploads:/app/uploads \
  bstock-backend-image:<previous-commit-sha>

# Or trigger a re-deployment of a previous commit
# Push the previous commit to trigger CI/CD
git log --oneline -5  # See recent commits
git push origin <previous-commit-hash>:claude/review-specs-multiproject-plan-01LHvz5h6ugNLQjWspwp3MR4 --force
```

---

## ✅ CI/CD Checklist

After setup, verify:
- [ ] Runner shows as "Idle" on GitHub
- [ ] All 5 secrets are configured
- [ ] Test push triggers workflow
- [ ] Workflow completes successfully
- [ ] Containers restart automatically
- [ ] API responds at https://api.ashreef.com/health
- [ ] Flutter app can connect to API
- [ ] Logs are accessible in Portainer

---

## 🎉 You're All Set!

Now every time you push code:
1. GitHub Actions automatically triggers
2. Your server builds and deploys
3. Zero-downtime updates
4. Health checks ensure stability
5. You get notified of success/failure

**Workflow Status:** https://github.com/alikhalidsherif/bstockv2/actions

**Deployment Time:** ~2-3 minutes from push to live

---

## 📞 Quick Reference

### Useful Commands

```bash
# Check runner status
sudo systemctl status actions.runner.*

# View runner logs
sudo journalctl -u actions.runner.* -f

# Restart runner
sudo systemctl restart actions.runner.*

# Manual deployment (view container status)
docker ps | grep bstock

# Restart a container manually
docker restart bstock-backend

# Force Watchtower check
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --run-once
```

### Important URLs

- **GitHub Actions:** https://github.com/alikhalidsherif/bstockv2/actions
- **Runners:** https://github.com/alikhalidsherif/bstockv2/settings/actions/runners
- **Secrets:** https://github.com/alikhalidsherif/bstockv2/settings/secrets/actions
- **API Health:** https://api.ashreef.com/health
- **Portainer:** http://your-server-ip:9000

---

**CI/CD Setup Complete! 🚀**

Push code and watch it automatically deploy to production!