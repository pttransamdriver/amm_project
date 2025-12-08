# Vercel Deployment Configuration

Quick guide for deploying the AMM frontend to Vercel.

---

## 🎯 Vercel Project Settings

### Build & Development Settings

| Setting | Value |
|---------|-------|
| **Framework Preset** | Create React App |
| **Build Command** | `npm run build` |
| **Output Directory** | `build` |
| **Install Command** | `npm install` |
| **Development Command** | `npm start` |

### Root Directory

- If **standalone project**: `./`
- If **in monorepo**: `amm_project`

---

## 🔐 Environment Variables

Add these in Vercel Dashboard → Settings → Environment Variables:

### Required Variables

```bash
# Network Configuration
REACT_APP_NETWORK=sepolia
REACT_APP_CHAIN_ID=11155111

# RPC URL (use your Alchemy or Infura key)
REACT_APP_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY

# Etherscan
REACT_APP_ETHERSCAN_URL=https://sepolia.etherscan.io
```

### Optional Variables

```bash
# App Configuration
REACT_APP_NAME=AMM DEX
REACT_APP_ENVIRONMENT=production
REACT_APP_DEBUG=false

# Feature Flags
REACT_APP_ENABLE_FLASHLOANS=true
REACT_APP_ENABLE_ARBITRAGE=true
REACT_APP_ENABLE_CHARTS=true

# Analytics (if using Google Analytics)
REACT_APP_GA_TRACKING_ID=UA-XXXXXXXXX-X
```

### How to Add Environment Variables

**Option 1: Vercel Dashboard**
1. Go to your project in Vercel
2. Click "Settings"
3. Click "Environment Variables"
4. Add each variable:
   - Name: `REACT_APP_NETWORK`
   - Value: `sepolia`
   - Environment: Production (check the box)
   - Click "Save"
5. Repeat for all variables
6. Redeploy to apply changes

**Option 2: Vercel CLI**
```bash
vercel env add REACT_APP_NETWORK production
# Enter: sepolia

vercel env add REACT_APP_CHAIN_ID production
# Enter: 11155111

vercel env add REACT_APP_SEPOLIA_RPC_URL production
# Enter: https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

vercel env add REACT_APP_ETHERSCAN_URL production
# Enter: https://sepolia.etherscan.io

# Redeploy
vercel --prod
```

---

## 📝 Deployment Methods

### Method 1: GitHub Integration (Recommended)

**Automatic deployments on every push!**

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Ready for deployment"
   git push origin main
   ```

2. **Import in Vercel**
   - Go to https://vercel.com/new
   - Click "Import Git Repository"
   - Select your repository
   - Configure settings (see above)
   - Click "Deploy"

3. **Automatic Updates**
   - Every push to `main` triggers a new deployment
   - Preview deployments for pull requests
   - Rollback to previous deployments anytime

### Method 2: Vercel CLI

**Manual deployments via command line**

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy to production
vercel --prod

# Deploy to preview
vercel
```

### Method 3: Drag & Drop

**Quick one-time deployment**

1. Build locally:
   ```bash
   npm run build
   ```

2. Go to https://vercel.com/new

3. Drag the `build` folder to the upload area

4. Configure environment variables

5. Click "Deploy"

---

## 🔄 Continuous Deployment

### Automatic Deployments

Vercel automatically deploys when you:
- Push to `main` branch → Production deployment
- Create pull request → Preview deployment
- Push to other branches → Preview deployment (optional)

### Deployment Branches

Configure in Vercel Dashboard → Settings → Git:

- **Production Branch:** `main` (or `master`)
- **Preview Branches:** All branches (or specific branches)

### Ignore Build Step

To prevent deployment on certain changes, Vercel uses the `ignoreCommand` in `vercel.json`:

```json
{
  "ignoreCommand": "git diff --quiet HEAD^ HEAD ./src ./public ./package.json"
}
```

This only deploys if changes are in `src/`, `public/`, or `package.json`.

---

## 🌐 Custom Domain (Optional)

### Add Custom Domain

1. Go to Vercel Dashboard → Settings → Domains
2. Click "Add"
3. Enter your domain (e.g., `amm.yourdomain.com`)
4. Follow DNS configuration instructions
5. Wait for DNS propagation (5-60 minutes)

### DNS Configuration

**For subdomain (amm.yourdomain.com):**
- Type: `CNAME`
- Name: `amm`
- Value: `cname.vercel-dns.com`

**For root domain (yourdomain.com):**
- Type: `A`
- Name: `@`
- Value: `76.76.21.21`

---

## 📊 Monitoring & Analytics

### Vercel Analytics

Enable in Dashboard → Analytics:
- Page views
- Unique visitors
- Top pages
- Geographic distribution
- Device types

### Performance Monitoring

View in Dashboard → Speed Insights:
- Core Web Vitals
- Lighthouse scores
- Performance metrics
- Recommendations

### Logs

View in Dashboard → Deployments → [Select Deployment] → Logs:
- Build logs
- Function logs
- Error logs

---

## 🐛 Troubleshooting

### Build Fails with Warnings

**Issue:** Build treats warnings as errors

**Solution:** Update `package.json`:
```json
{
  "scripts": {
    "build": "CI=false react-scripts build"
  }
}
```

### Environment Variables Not Working

**Issue:** Variables not accessible in app

**Solution:**
1. Ensure variables start with `REACT_APP_`
2. Redeploy after adding variables
3. Check variable is set for "Production" environment
4. Clear cache and redeploy

### Wrong Network Showing

**Issue:** App connects to wrong network

**Solution:**
1. Verify `REACT_APP_CHAIN_ID=11155111`
2. Check `src/config.json` has Sepolia addresses
3. Clear browser cache
4. Reconnect MetaMask

---

## ✅ Pre-Deployment Checklist

- [ ] All tests passing locally
- [ ] `npm run build` succeeds
- [ ] `src/config.json` has Sepolia addresses (Chain ID: 11155111)
- [ ] Environment variables prepared
- [ ] GitHub repository created and pushed
- [ ] Vercel account created
- [ ] Custom domain ready (optional)

---

## 🚀 Quick Deploy Commands

```bash
# Full deployment flow
git add .
git commit -m "Deploy to production"
git push origin main

# Vercel will automatically deploy!

# Or manual CLI deployment
vercel --prod
```

---

## 📚 Additional Resources

- **Vercel Docs:** https://vercel.com/docs
- **Create React App Deployment:** https://create-react-app.dev/docs/deployment/
- **Environment Variables:** https://vercel.com/docs/environment-variables
- **Custom Domains:** https://vercel.com/docs/custom-domains

---

**Your AMM will be live at:** `https://your-project.vercel.app` 🎉

