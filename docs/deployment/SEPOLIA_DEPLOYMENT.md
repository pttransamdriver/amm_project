# 🚀 Sepolia Deployment & Vercel Hosting Guide

Complete guide to deploy your AMM project to Sepolia testnet and host the frontend on Vercel.

---

## 📋 Prerequisites

### 1. Required Accounts & API Keys

- [ ] **Ethereum Wallet** with Sepolia ETH
  - Get Sepolia ETH from: https://sepoliafaucet.com/
  - Recommended: 0.5+ ETH for deployment and testing
  
- [ ] **Alchemy Account** (Recommended) or Infura
  - Sign up: https://www.alchemy.com/
  - Create a new app for Sepolia network
  - Copy your API key
  
- [ ] **Etherscan Account** (for contract verification)
  - Sign up: https://etherscan.io/
  - Get API key: https://etherscan.io/myapikey
  
- [ ] **Vercel Account** (for frontend hosting)
  - Sign up: https://vercel.com/
  - Connect your GitHub account

### 2. Required Software

```bash
# Node.js (v18 or higher)
node --version  # Should be v18+

# npm (comes with Node.js)
npm --version

# Git
git --version

# Vercel CLI (optional but recommended)
npm install -g vercel
```

---

## 🔧 Part 1: Environment Setup

### Step 1: Create .env File

```bash
cd amm_project
cp .env.example .env
```

### Step 2: Configure .env

Edit `.env` with your actual values:

```bash
# Sepolia RPC URL (Alchemy)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY

# Your wallet private key (NEVER share this!)
# Export from MetaMask: Account Details > Export Private Key
PRIVATE_KEY=your_private_key_here_without_0x_prefix

# Etherscan API Key (for contract verification)
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Optional: Gas reporting
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
REPORT_GAS=false
```

⚠️ **SECURITY WARNING:**
- NEVER commit `.env` to Git
- Use a test wallet, NOT your main wallet
- Keep your private key secure

---

## 📦 Part 2: Smart Contract Deployment to Sepolia

### Step 1: Install Dependencies

```bash
npm install
```

### Step 2: Compile Contracts

```bash
npx hardhat compile
```

Expected output:
```
Compiled 15 Solidity files successfully
```

### Step 3: Run Tests (Optional but Recommended)

```bash
npx hardhat test
```

Expected: All 29 tests should pass ✅

### Step 4: Deploy to Sepolia

```bash
npx hardhat run scripts/deploy-sepolia.js --network sepolia
```

**Expected Output:**
```
🚀 Starting Sepolia Deployment...

📋 Deployment Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Network: sepolia
Chain ID: 11155111
Deployer: 0x...
Balance: 0.5 ETH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Deploying DAPP Token...
✅ DAPP Token deployed to: 0x...

📦 Deploying USD Token...
✅ USD Token deployed to: 0x...

📦 Deploying AMM Contract...
✅ AMM deployed to: 0x...

📦 Deploying Price Oracle...
✅ Price Oracle deployed to: 0x...

📦 Deploying FlashLoan Hub...
✅ FlashLoan Hub deployed to: 0x...

📦 Deploying SimpleArbitrage Strategy...
✅ SimpleArbitrage deployed to: 0x...

📦 Deploying TriangularArbitrage Strategy...
✅ TriangularArbitrage deployed to: 0x...

🎉 Deployment Complete!
```

### Step 5: Deploy to Vercel (Option A: Web UI)

1. **Go to Vercel Dashboard**
   - Visit: https://vercel.com/dashboard
   - Click "Add New Project"

2. **Import Git Repository**
   - Select your GitHub repository
   - Click "Import"

3. **Configure Project**
   - **Framework Preset:** Create React App
   - **Root Directory:** `amm_project` (if in monorepo) or `./` (if standalone)
   - **Build Command:** `npm run build`
   - **Output Directory:** `build`
   - **Install Command:** `npm install`

4. **Add Environment Variables**

   Click "Environment Variables" and add:

   | Name | Value |
   |------|-------|
   | `REACT_APP_NETWORK` | `sepolia` |
   | `REACT_APP_CHAIN_ID` | `11155111` |
   | `REACT_APP_SEPOLIA_RPC_URL` | `https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY` |
   | `REACT_APP_ETHERSCAN_URL` | `https://sepolia.etherscan.io` |

5. **Deploy**
   - Click "Deploy"
   - Wait 2-3 minutes for build to complete
   - Your app will be live at: `https://your-project.vercel.app`

### Step 6: Deploy to Vercel (Option B: CLI)

```bash
# Login to Vercel
vercel login

# Deploy to production
vercel --prod

# Follow the prompts:
# - Set up and deploy? Yes
# - Which scope? Your account
# - Link to existing project? No
# - Project name? amm-dex (or your choice)
# - Directory? ./ (or amm_project if in monorepo)
# - Override settings? No
```

**Add environment variables via CLI:**

```bash
vercel env add REACT_APP_NETWORK production
# Enter: sepolia

vercel env add REACT_APP_CHAIN_ID production
# Enter: 11155111

vercel env add REACT_APP_SEPOLIA_RPC_URL production
# Enter: https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

vercel env add REACT_APP_ETHERSCAN_URL production
# Enter: https://sepolia.etherscan.io
```

**Redeploy with environment variables:**

```bash
vercel --prod
```

---

## ✅ Part 4: Post-Deployment Configuration

### Step 1: Approve Arbitrage Strategies

The FlashLoanHub requires strategies to be whitelisted. Connect to Sepolia and run:

```bash
npx hardhat run scripts/approve-strategies.js --network sepolia
```

Or manually via Etherscan:
1. Go to FlashLoanHub contract on Etherscan
2. Click "Write Contract"
3. Connect wallet
4. Call `approveStrategy(address)` with SimpleArbitrage address
5. Call `approveStrategy(address)` with TriangularArbitrage address

### Step 2: Add Initial Liquidity

You can add liquidity via:

**Option A: Frontend UI**
1. Visit your Vercel deployment
2. Connect MetaMask (switch to Sepolia)
3. Go to "Deposit" tab
4. Approve tokens
5. Add liquidity (e.g., 10,000 DAPP + 10,000 USD)

**Option B: Script**
```bash
npx hardhat run scripts/seed.js --network sepolia
```

### Step 3: Test the Application

1. **Visit your Vercel URL**
   - Example: `https://amm-dex.vercel.app`

2. **Connect MetaMask**
   - Switch to Sepolia network
   - Connect your wallet

3. **Test Swap Functionality**
   - Try swapping DAPP for USD
   - Check slippage protection works
   - Verify transaction on Etherscan

4. **Test Liquidity Functions**
   - Add liquidity
   - Remove liquidity
   - Check LP shares

5. **Test Charts**
   - View price charts
   - Check liquidity charts
   - Verify data updates

---

## 🔍 Part 5: Monitoring & Maintenance

### Monitor Contract Activity

**Etherscan:**
- DAPP Token: `https://sepolia.etherscan.io/address/<DAPP_ADDRESS>`
- USD Token: `https://sepolia.etherscan.io/address/<USD_ADDRESS>`
- AMM: `https://sepolia.etherscan.io/address/<AMM_ADDRESS>`

**Check:**
- Transaction history
- Token holders
- Contract interactions
- Event logs

### Vercel Deployment Monitoring

**Dashboard:** https://vercel.com/dashboard

**Monitor:**
- Build logs
- Deployment status
- Analytics (visitors, page views)
- Error logs

### Update Deployment

**When you make changes:**

```bash
# Commit changes
git add .
git commit -m "Update: description of changes"
git push origin main

# Vercel will automatically redeploy!
```

**Manual redeploy:**
```bash
vercel --prod
```

---

## 🐛 Troubleshooting

### Issue: "Insufficient funds for gas"

**Solution:**
- Get more Sepolia ETH from faucet
- Check your wallet balance
- Reduce gas limit if possible

### Issue: "Contract verification failed"

**Solution:**
```bash
# Make sure compiler version matches
# Check hardhat.config.js: solidity version should be 0.8.28
# Verify with exact constructor arguments
npx hardhat verify --network sepolia <ADDRESS> <ARG1> <ARG2>
```

### Issue: "Transaction reverted"

**Common causes:**
- Slippage tolerance too low
- Insufficient token balance
- Token not approved
- Trade cooldown active

**Solution:**
- Check error message in MetaMask
- Increase slippage tolerance
- Approve tokens first
- Wait for cooldown period

### Issue: "Cannot connect to Sepolia"

**Solution:**
- Check RPC URL in .env
- Verify Alchemy/Infura API key
- Try alternative RPC:
  ```
  https://rpc.sepolia.org
  https://sepolia.infura.io/v3/YOUR_KEY
  ```

### Issue: "Vercel build fails"

**Solution:**
```bash
# Test build locally first
npm run build

# Check for errors
# Common issues:
# - Missing dependencies: npm install
# - Environment variables not set
# - Build warnings treated as errors
```

**Fix build warnings:**
Add to `package.json`:
```json
"scripts": {
  "build": "CI=false react-scripts build"
}
```

### Issue: "MetaMask shows wrong network"

**Solution:**
- Manually add Sepolia to MetaMask:
  - Network Name: Sepolia
  - RPC URL: https://sepolia.infura.io/v3/YOUR_KEY
  - Chain ID: 11155111
  - Currency Symbol: ETH
  - Block Explorer: https://sepolia.etherscan.io

---

## 📊 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing (29/29)
- [ ] Contracts compiled successfully
- [ ] .env file configured
- [ ] Sepolia ETH in wallet (0.5+ ETH)
- [ ] Alchemy/Infura API key obtained
- [ ] Etherscan API key obtained

### Smart Contract Deployment
- [ ] Deployed to Sepolia
- [ ] All 7 contracts deployed successfully
- [ ] Contract addresses saved
- [ ] config.json updated
- [ ] Contracts verified on Etherscan
- [ ] Strategies approved in FlashLoanHub
- [ ] Initial liquidity added

### Frontend Deployment
- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Vercel project created
- [ ] Environment variables configured
- [ ] Build successful
- [ ] Deployment live
- [ ] MetaMask connection works
- [ ] Swap functionality tested
- [ ] Liquidity functions tested

### Post-Deployment
- [ ] Contract addresses documented
- [ ] Deployment info saved
- [ ] Team notified
- [ ] Monitoring set up
- [ ] Documentation updated

---

## 🎯 Next Steps After Deployment

1. **Security Audit** (Recommended before mainnet)
   - Engage professional auditors
   - Run bug bounty program
   - Community review

2. **Add More Features**
   - TWAP oracle integration
   - Circuit breakers
   - Dynamic fees
   - Multi-hop routing

3. **Marketing & Community**
   - Create documentation site
   - Write blog posts
   - Engage on social media
   - Build community

4. **Mainnet Preparation**
   - Professional audit complete
   - 4+ weeks of testnet operation
   - No critical bugs found
   - Insurance coverage (optional)

---

## 📚 Additional Resources

- **Sepolia Faucet:** https://sepoliafaucet.com/
- **Alchemy Dashboard:** https://dashboard.alchemy.com/
- **Etherscan Sepolia:** https://sepolia.etherscan.io/
- **Vercel Docs:** https://vercel.com/docs
- **Hardhat Docs:** https://hardhat.org/docs
- **MetaMask Docs:** https://docs.metamask.io/

---

## 🆘 Support

If you encounter issues:

1. Check this troubleshooting guide
2. Review deployment logs
3. Check Etherscan for transaction details
4. Review Vercel build logs
5. Open an issue on GitHub

---

**Congratulations! Your AMM is now live on Sepolia and hosted on Vercel! 🎉**
**Save these contract addresses!** They'll be automatically added to `src/config.json`.

### Step 5: Verify Contracts on Etherscan

The deployment script will output verification commands. Run them:

```bash
npx hardhat verify --network sepolia <DAPP_ADDRESS> "Dapp Token" "DAPP" "1000000"
npx hardhat verify --network sepolia <USD_ADDRESS> "USD Token" "USD" "1000000"
npx hardhat verify --network sepolia <AMM_ADDRESS> <DAPP_ADDRESS> <USD_ADDRESS>
npx hardhat verify --network sepolia <ORACLE_ADDRESS>
npx hardhat verify --network sepolia <FLASHLOAN_HUB_ADDRESS>
npx hardhat verify --network sepolia <SIMPLE_ARB_ADDRESS> <FLASHLOAN_HUB_ADDRESS>
npx hardhat verify --network sepolia <TRIANGULAR_ARB_ADDRESS> <FLASHLOAN_HUB_ADDRESS>
```

✅ **Success:** You'll see "Successfully verified contract" for each

---

## 🌐 Part 3: Frontend Deployment to Vercel

### Step 1: Update config.json

Verify that `src/config.json` has been updated with Sepolia addresses (Chain ID: 11155111):

```json
{
  "31337": {
    // ... localhost addresses ...
  },
  "11155111": {
    "dapp": { "address": "0x..." },
    "usd": { "address": "0x..." },
    "amm": { "address": "0x..." },
    "oracle": { "address": "0x..." },
    "flashLoanHub": { "address": "0x..." },
    "simpleArbitrage": { "address": "0x..." },
    "triangularArbitrage": { "address": "0x..." }
  }
}
```

### Step 2: Test Build Locally

```bash
npm run build
```

Expected: Build completes successfully, creates `build/` directory

### Step 3: Initialize Git Repository (if not already)

```bash
git init
git add .
git commit -m "Initial commit - AMM project ready for deployment"
```

### Step 4: Push to GitHub

```bash
# Create a new repository on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```


