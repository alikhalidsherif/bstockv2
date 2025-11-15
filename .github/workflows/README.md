# GitHub Actions Workflows

This directory contains CI/CD workflows for the Bstock project.

## Workflows

### 1. `deploy.yml` - Production Deployment
**Trigger:** Push to main or feature branches
**Runner:** Self-hosted (your home server)
**Purpose:** Automatically build and deploy to production

**What it does:**
- Pulls latest code
- Creates .env.production from GitHub Secrets
- Builds Docker images
- Deploys with docker-compose
- Runs health checks
- Cleans up old images

### 2. `test.yml` - Build and Test
**Trigger:** Pull requests and pushes to non-main branches
**Runner:** GitHub-hosted (Ubuntu)
**Purpose:** Validate code before merge

**What it does:**
- Tests Go backend (fmt, vet, build)
- Tests Flutter frontend (analyze, build)
- Tests Docker image build

### 3. `build-ghcr.yml.example` - GitHub Container Registry (Optional)
**Trigger:** Not active by default
**Purpose:** Alternative deployment using GHCR

**To enable:**
```bash
mv build-ghcr.yml.example build-ghcr.yml
```

## Setup Instructions

See `../CI_CD_SETUP.md` for complete setup guide.

## Quick Start

1. **Install self-hosted runner on your server**
2. **Add GitHub Secrets** (5 required secrets)
3. **Push code** - deployment happens automatically!

## Status Badges

Add to README.md:

```markdown
![Deploy](https://github.com/alikhalidsherif/bstockv2/workflows/Deploy%20to%20Production/badge.svg)
![Tests](https://github.com/alikhalidsherif/bstockv2/workflows/Build%20and%20Test/badge.svg)
```
