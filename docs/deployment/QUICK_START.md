# 🚀 Quick Deployment Reference

**Fast reference for deploying AMM to Sepolia + Vercel**

---

## ⚡ Quick Start (5 Steps)

### 1️⃣ Setup Environment

```bash
cd amm_project
cp .env.example .env
# Edit .env with your keys
```

### 2️⃣ Deploy Contracts to Sepolia

```bash
npm install
npx hardhat compile
npx hardhat run scripts/deploy-sepolia.js --network sepolia
```

### 3️⃣ Verify Contracts (Optional)

```bash
# Copy commands from deployment output
npx hardhat verify --network sepolia <ADDRESS> <ARGS>
```

### 4️⃣ Approve Strategies

```bash
npx hardhat run scripts/approve-strategies.js --network sepolia
```

### 5️⃣ Deploy to Vercel

```bash
# Option A: CLI
vercel --prod

# Option B: Web UI
# Push to GitHub, then import in Vercel dashboard
```

---

## 📋 Required Environment Variables

### For .env (Local Development & Deployment)

```bash
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=your_private_key_without_0x
ETHERSCAN_API_KEY=your_etherscan_key
```

### For Vercel (Production Frontend)

Add in Vercel Dashboard → Settings → Environment Variables:

| Variable | Value |
|----------|-------|
| `REACT_APP_NETWORK` | `sepolia` |
| `REACT_APP_CHAIN_ID` | `11155111` |
| `REACT_APP_SEPOLIA_RPC_URL` | `https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY` |
| `REACT_APP_ETHERSCAN_URL` | `https://sepolia.etherscan.io` |

---

## 🔗 Important Links

### Get Resources
- **Sepolia ETH:** https://sepoliafaucet.com/
- **Alchemy API:** https://dashboard.alchemy.com/
- **Etherscan API:** https://etherscan.io/myapikey
- **Vercel:** https://vercel.com/

### Monitor Deployment
- **Sepolia Explorer:** https://sepolia.etherscan.io/
- **Vercel Dashboard:** https://vercel.com/dashboard

---

## 🐛 Common Issues & Fixes

### "Insufficient funds"
```bash
# Get Sepolia ETH from faucet
# Need ~0.5 ETH for deployment
```

### "Invalid API key"
```bash
# Check .env file
# Verify Alchemy/Infura key is correct
# Try alternative RPC: https://rpc.sepolia.org
```

### "Vercel build fails"
```bash
# Test locally first
npm run build

# If warnings cause failure, update package.json:
"build": "CI=false react-scripts build"
```

### "MetaMask wrong network"
```bash
# Add Sepolia manually:
# Network: Sepolia
# RPC: https://sepolia.infura.io/v3/YOUR_KEY
# Chain ID: 11155111
# Symbol: ETH
```

---

## 📦 Deployed Contracts

After deployment, contracts will be at:

```
DAPP Token:           0x...
USD Token:            0x...
AMM:                  0x...
Price Oracle:         0x...
FlashLoan Hub:        0x...
SimpleArbitrage:      0x...
TriangularArbitrage:  0x...
```

Addresses automatically saved to `src/config.json` under chain ID `11155111`.

---

## ✅ Deployment Checklist

**Pre-Deployment:**
- [ ] .env configured
- [ ] Sepolia ETH in wallet (0.5+)
- [ ] Tests passing (29/29)

**Smart Contracts:**
- [ ] Deployed to Sepolia
- [ ] Verified on Etherscan
- [ ] Strategies approved
- [ ] Liquidity added

**Frontend:**
- [ ] Pushed to GitHub
- [ ] Vercel env vars set
- [ ] Deployed successfully
- [ ] Tested on Sepolia

---

## 🎯 Post-Deployment

### Add Liquidity
```bash
npx hardhat run scripts/seed.js --network sepolia
```

### Test Application
1. Visit Vercel URL
2. Connect MetaMask (Sepolia)
3. Test swap functionality
4. Test liquidity functions

### Monitor
- Check Etherscan for transactions
- Monitor Vercel analytics
- Watch for errors in logs

---

## 📞 Support

**Full Guide:** See `SEPOLIA_VERCEL_DEPLOYMENT.md`  
**Technical Details:** See `DEEPDIVE.md`  
**Security Info:** See `COMPREHENSIVE_SECURITY_AUDIT.md`

---

**Total Time:** ~30 minutes (excluding verification wait times)

