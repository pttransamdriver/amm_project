# AMM Decentralized Exchange

A full-stack Automated Market Maker (AMM) decentralized exchange built with Solidity smart contracts and React frontend. Users can swap tokens, provide liquidity, and earn fees from trading activity.

## Features

- **Token Swapping**: Exchange tokens with 0.3% trading fees using constant product formula
- **Liquidity Provision**: Add/remove liquidity to earn trading fees
- **Real-time Charts**: Price visualization and trading history
- **Multi-network Support**: Localhost, Sepolia testnet, and Ethereum mainnet
- **Gas Optimized**: Compiler optimizations and detailed gas reporting
- **Reentrancy Protection**: Secure smart contract implementation

## Tech Stack

- **Smart Contracts**: Solidity ^0.8.28, Hardhat development environment
- **Frontend**: React 18, Redux Toolkit for state management, React Bootstrap UI
- **Blockchain Integration**: Ethers.js v6, MetaMask wallet connection
- **Visualization**: ApexCharts for price charts and trading data
- **Testing**: Comprehensive test suite with gas reporting

## Quick Start

### Prerequisites
- Node.js and npm
- MetaMask browser extension

### Installation

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Start local blockchain**:
   ```bash
   npx hardhat node
   ```

3. **Deploy contracts** (in new terminal):
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

4. **Seed with initial liquidity**:
   ```bash
   npx hardhat run scripts/seed.js --network localhost
   ```

5. **Start React frontend**:
   ```bash
   npm start
   ```

6. **Connect MetaMask** to localhost:8545 (Chain ID: 31337)

## Smart Contracts

- **AutomatedMarketMaker.sol**: Core AMM logic with liquidity pools and swapping
- **Token.sol**: ERC-20 token implementation with gas optimizations

## Gas Optimization

Significant effort has been invested in optimizing gas consumption through **bytestacking** techniques:

- **Variable Packing**: Strategic ordering of state variables to minimize storage slots
- **Immutable Tokens**: Token addresses declared as `immutable` for reduced gas costs
- **Unchecked Arithmetic**: Safe use of `unchecked` blocks for overflow-protected operations
- **Constant Optimization**: Fee calculations using constants (`FEE_NUMERATOR`, `FEE_DENOMINATOR`)
- **Efficient Data Types**: `uint8` for decimals and lock states to optimize storage
- **Compiler Optimization**: Enabled with 200 runs for deployment cost vs runtime efficiency balance

These optimizations significantly reduce transaction costs for users while maintaining security and functionality.

## Available Commands

### Blockchain Development
```bash
npx hardhat test                    # Run smart contract tests
GAS_REPORT=true npx hardhat test    # Run tests with gas reporting
npx hardhat node                    # Start local blockchain
npx hardhat run scripts/deploy.js   # Deploy contracts
npx hardhat run scripts/seed.js     # Add initial liquidity
```

### Frontend Development
```bash
npm start      # Start development server
npm run build  # Build for production
npm test       # Run React tests
```

## Network Configuration

- **Localhost**: http://127.0.0.1:8545 (Chain ID: 31337)
- **Sepolia Testnet**: Requires SEPOLIA_RPC_URL and PRIVATE_KEY in .env
- **Ethereum Mainnet**: Requires MAINNET_RPC_URL and PRIVATE_KEY in .env

## Environment Setup

Copy `.env.example` to `.env` and configure:
```bash
SEPOLIA_RPC_URL=your_sepolia_rpc_url
MAINNET_RPC_URL=your_mainnet_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
REPORT_GAS=true
```

## Project Structure

```
├── contracts/          # Solidity smart contracts
├── scripts/           # Deployment and seeding scripts
├── test/              # Smart contract tests
├── src/
│   ├── components/    # React components
│   ├── store/         # Redux store and interactions
│   └── abis/          # Contract ABIs
└── public/            # Static assets
```

## License

ISC
