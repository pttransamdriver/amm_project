# 🏦 Automated Market Maker (AMM) DEX

A production-ready decentralized exchange (DEX) built with Solidity and React, featuring advanced security protections, flashloan arbitrage, and a comprehensive trading interface.

[![Tests](https://img.shields.io/badge/tests-29%20passing-brightgreen)]()
[![Solidity](https://img.shields.io/badge/solidity-0.8.28-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## 🌟 Key Features

### Core AMM Functionality
- ✅ **Constant Product Formula** (x * y = k)
- ✅ **Token Swapping** with slippage protection
- ✅ **Liquidity Provision** with LP tokens
- ✅ **Real-time Price Charts** and analytics
- ✅ **Multi-network Support** (Localhost, Sepolia)

### Security Features (10 Protections)
- 🔒 **Reentrancy Protection** (OpenZeppelin)
- 🔒 **Slippage Protection** (user-defined limits + deadlines)
- 🔒 **Minimum Liquidity Lock** (1000 wei permanent lock)
- 🔒 **Global Price Impact Limits** (10% per block)
- 🔒 **Strategy Whitelist** (owner-controlled approvals)
- 🔒 **Anti-Wash Trading** (6 protections)
- 🔒 **Arithmetic Safety** (Solidity 0.8.28)
- 🔒 **Access Control** (Ownable pattern)
- 🔒 **Trade Cooldowns** (1 block minimum)
- 🔒 **Flashloan Self-Trading Prevention**

### FlashLoan System
- ⚡ **Multi-DEX Support** (Aave V3, Uniswap V3, Balancer V2, Custom AMM)
- ⚡ **Arbitrage Strategies** (Simple, Triangular, Custom)
- ⚡ **Strategy Whitelist** (security-first approach)
- ⚡ **Fee Structure** (0.09% flashloan fee)

---

## 📁 Project Structure

```
amm_project/
├── contracts/              # Smart contracts
│   ├── core/              # Core AMM contracts
│   │   ├── AMM.sol        # Main AMM contract
│   │   ├── Token.sol      # ERC-20 token
│   │   └── PriceOracle.sol
│   ├── flashloan/         # FlashLoan system
│   │   ├── FlashLoanHub.sol
│   │   ├── FlashArbitrage.sol
│   │   └── IFlashLoanReceiver.sol
│   ├── strategies/        # Arbitrage strategies
│   │   ├── SimpleArbitrage.sol
│   │   └── TriangularArbitrage.sol
│   ├── interfaces/        # External DEX interfaces
│   └── mocks/            # Test mocks
├── scripts/               # Deployment & management
│   ├── deployment/       # Deployment scripts
│   ├── management/       # Admin scripts
│   └── testing/          # Test utilities
├── test/                 # Test suite (29 tests)
├── src/                  # React frontend
│   ├── components/       # UI components
│   ├── store/           # Redux state management
│   └── abis/            # Contract ABIs
├── docs/                 # Documentation
│   ├── deployment/      # Deployment guides
│   ├── security/        # Security documentation
│   ├── technical/       # Technical deep dives
│   └── archive/         # Historical docs
├── hardhat.config.js     # Hardhat configuration
├── vercel.json          # Vercel deployment config
└── package.json         # Dependencies
```

---

## 🚀 Quick Start

### Prerequisites

- Node.js v18+
- npm or yarn
- MetaMask browser extension

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd amm_project

# Install dependencies
npm install
```

### Local Development

```bash
# Start local Hardhat node
npx hardhat node

# Deploy contracts (in another terminal)
npx hardhat run scripts/deployment/deploy.js --network localhost

# Add initial liquidity
npx hardhat run scripts/management/seed.js --network localhost

# Start React frontend
npm start
```

Visit `http://localhost:3000` and connect MetaMask to localhost:8545

---

## 🧪 Testing

```bash
# Run all tests
npx hardhat test

# Run with gas reporting
REPORT_GAS=true npx hardhat test

# Run specific test file
npx hardhat test test/AMM.js
```

**Test Coverage:** 29/29 tests passing ✅

---

## 📦 Deployment

### Sepolia Testnet

```bash
# Configure .env with Sepolia RPC URL and private key
# Deploy to Sepolia
npx hardhat run scripts/deployment/deploy-sepolia.js --network sepolia

# Approve arbitrage strategies
npx hardhat run scripts/management/approve-strategies.js --network sepolia

# Add initial liquidity
npx hardhat run scripts/management/seed.js --network sepolia
```

### Vercel (Frontend)

```bash
# Build for production
npm run build

# Deploy to Vercel
vercel --prod
```

**📚 Detailed Guides:**
- [Quick Start Guide](./docs/deployment/QUICK_START.md)
- [Sepolia Deployment](./docs/deployment/SEPOLIA_DEPLOYMENT.md)
- [Vercel Setup](./docs/deployment/VERCEL_SETUP.md)

---

## 📚 Documentation

### For Users
- **[README](./README.md)** - This file
- **[Quick Start](./docs/deployment/QUICK_START.md)** - Fast deployment guide

### For Developers
- **[Architecture](./docs/technical/ARCHITECTURE.md)** - Technical deep dive
- **[FlashLoan Guide](./docs/technical/FLASHLOAN_GUIDE.md)** - FlashLoan system details

### For Security
- **[Security Audit](./docs/security/SECURITY_AUDIT.md)** - Comprehensive security analysis
- **[Security Features](./docs/security/SECURITY_FIXES.md)** - Implemented protections

### For Deployment
- **[Deployment Summary](./docs/deployment/SUMMARY.md)** - Overview
- **[Sepolia Guide](./docs/deployment/SEPOLIA_DEPLOYMENT.md)** - Testnet deployment
- **[Vercel Guide](./docs/deployment/VERCEL_SETUP.md)** - Frontend hosting

---

## 🛠️ Technology Stack

### Smart Contracts
- **Solidity** 0.8.28
- **Hardhat** 2.22.18
- **OpenZeppelin** Contracts
- **Ethers.js** v6.14.4

### Frontend
- **React** 18.3.1
- **Redux Toolkit** 2.5.0
- **Bootstrap** 5.3.3
- **ApexCharts** 3.54.1
- **Ethers.js** v6.14.4

### Testing & Development
- **Hardhat Network** (local blockchain)
- **Chai** (assertions)
- **Hardhat Gas Reporter**
- **Hardhat Verify** (Etherscan)

---

## 🔐 Security

This project has undergone extensive security hardening:

- ✅ **10 Security Protections** implemented
- ✅ **6 Anti-Wash-Trading** mechanisms
- ✅ **Comprehensive Test Suite** (29 tests)
- ✅ **Gas Optimizations** applied
- ⚠️ **Professional Audit Recommended** before mainnet

**See:** [Security Audit](./docs/security/SECURITY_AUDIT.md) for details

---

## 📊 Contract Addresses

### Localhost (Chain ID: 31337)
See `src/config.json`

### Sepolia (Chain ID: 11155111)
Deployed addresses will be added to `src/config.json` after deployment

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## 🆘 Support

- **Documentation:** See `docs/` folder
- **Issues:** Open a GitHub issue
- **Security:** Report vulnerabilities privately

---

**Built with ❤️ for the Ethereum community**

