# FlashLoan Arbitrage Platform

A sophisticated DeFi platform combining an Automated Market Maker (AMM) with flashloan arbitrage capabilities. Built with gas-optimized Solidity smart contracts and a React frontend, this platform enables users to swap tokens, provide liquidity, and execute profitable arbitrage strategies across multiple DEXs.

## Core Features

### AMM Exchange
- **Token Swapping**: Exchange tokens with 0.3% trading fees using constant product formula
- **Liquidity Provision**: Add/remove liquidity to earn trading fees
- **Real-time Charts**: Price visualization and trading history
- **Gas Optimized**: Bytestacking techniques for minimal transaction costs
- **Reentrancy Protection**: Secure smart contract implementation

### Flashloan Arbitrage
- **Cross-DEX Arbitrage**: Execute profitable trades between Uniswap V3, SushiSwap, and internal AMM
- **Flashloan Integration**: Borrow capital without collateral for arbitrage opportunities
- **Price Oracle**: Real-time price comparison across multiple DEXs
- **Automated Strategies**: Smart contracts automatically identify and execute profitable trades
- **Fee Collection**: 0.05% flashloan fee generates platform revenue

### Multi-DEX Integration
- **Uniswap V3**: Access to concentrated liquidity and advanced routing
- **SushiSwap**: Alternative pricing and routing for arbitrage opportunities
- **Price Discovery**: Automated detection of arbitrage opportunities
- **Mock Testing**: Local development environment with simulated DEXs

## Tech Stack

- **Smart Contracts**: Solidity ^0.8.28, Hardhat development environment
- **DeFi Integration**: Uniswap V3 SDK, SushiSwap interfaces, flashloan protocols
- **Frontend**: React 18, Redux Toolkit for state management, React Bootstrap UI
- **Blockchain Integration**: Ethers.js v6, MetaMask wallet connection
- **Visualization**: ApexCharts for price charts and arbitrage analytics
- **Testing**: Comprehensive test suite with mock DEX contracts and gas reporting
- **Development**: Local blockchain with simulated multi-DEX environment

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

## Smart Contracts Architecture

### Core Contracts
- **AutomatedMarketMaker.sol**: Core AMM with flashloan functionality and liquidity pools
- **Token.sol**: Gas-optimized ERC-20 token implementation
- **FlashArbitrage.sol**: Cross-DEX arbitrage execution engine
- **PriceOracle.sol**: Multi-DEX price comparison and opportunity detection

### Integration Contracts
- **IFlashLoanReceiver.sol**: Interface for flashloan callback handling
- **Uniswap V3 Integration**: Router and quoter interfaces for price discovery
- **SushiSwap Integration**: Router interface for alternative liquidity access

### Testing Infrastructure
- **MockUniswapV3.sol**: Local testing environment for Uniswap integration
- **MockSushiSwap.sol**: Local testing environment for SushiSwap integration
- **Arbitrage Testing Scripts**: Automated testing of profit opportunities

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
npx hardhat test                         # Run smart contract tests
GAS_REPORT=true npx hardhat test         # Run tests with gas reporting
npx hardhat node                         # Start local blockchain
npx hardhat run scripts/deploy.js        # Deploy production contracts
npx hardhat run scripts/deploy-test.js   # Deploy test environment with mock DEXs
npx hardhat run scripts/seed.js          # Add initial liquidity
npx hardhat run scripts/test-arbitrage.js # Test arbitrage opportunities
```

### Frontend Development
```bash
npm start      # Start development server
npm run build  # Build for production
npm test       # Run React tests
```

### Arbitrage Testing
```bash
# Deploy test environment
npx hardhat run scripts/deploy-test.js --network localhost

# Test arbitrage opportunities
npx hardhat run scripts/test-arbitrage.js --network localhost
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
├── contracts/
│   ├── AMM.sol                    # Core AMM with flashloan functionality
│   ├── Token.sol                  # Gas-optimized ERC-20 implementation
│   ├── FlashArbitrage.sol         # Cross-DEX arbitrage engine
│   ├── PriceOracle.sol            # Multi-DEX price comparison
│   ├── interfaces/                # External protocol interfaces
│   ├── mocks/                     # Mock contracts for testing
│   │   ├── MockUniswapV3.sol      # Simulated Uniswap V3 for testing
│   │   └── MockSushiSwap.sol      # Simulated SushiSwap for testing
│   └── strategies/                # Arbitrage strategy implementations
├── scripts/
│   ├── deploy.js                  # Production deployment
│   ├── deploy-test.js             # Test environment deployment
│   ├── seed.js                    # Initial liquidity seeding
│   └── test-arbitrage.js          # Arbitrage opportunity testing
├── test/                          # Comprehensive smart contract tests
├── src/
│   ├── components/                # React UI components
│   │   ├── FlashLoan.js           # Flashloan interface
│   │   ├── Swap.js                # Token swapping
│   │   ├── Deposit.js             # Liquidity provision
│   │   └── Charts.js              # Price visualization
│   ├── store/                     # Redux state management
│   │   ├── reducers/flashloan.js  # Flashloan state management
│   │   └── interactions.js        # Blockchain interactions
│   └── abis/                      # Contract ABIs
└── public/                        # Static assets
```

## Revenue Model

### Platform Fees
- **AMM Trading Fees**: 0.3% on all swaps (distributed to liquidity providers)
- **Flashloan Fees**: 0.05% on all flashloan transactions
- **Arbitrage Profits**: Platform retains profits from successful arbitrage trades

### Liquidity Provider Benefits
- **Trading Fee Share**: Earn from all AMM trading activity
- **Increased Volume**: Arbitrage activity drives higher trading volumes
- **Impermanent Loss Protection**: Arbitrage helps maintain price stability

## Arbitrage Strategies

### Simple Arbitrage
1. **Price Discovery**: Oracle identifies price differences between DEXs
2. **Flashloan Execution**: Borrow tokens from AMM without collateral
3. **Cross-DEX Trading**: Buy low on one DEX, sell high on another
4. **Profit Realization**: Repay flashloan + fee, retain profit

### Triangular Arbitrage
1. **Multi-Token Opportunities**: Identify price inefficiencies across token pairs
2. **Complex Routing**: Execute multi-hop trades for maximum profit
3. **Gas Optimization**: Minimize transaction costs to maximize returns

## Getting Started with Arbitrage

### 1. Local Development Setup
```bash
# Install dependencies
npm install

# Start local blockchain
npx hardhat node

# Deploy test environment (new terminal)
npx hardhat run scripts/deploy-test.js --network localhost

# Test arbitrage opportunities
npx hardhat run scripts/test-arbitrage.js --network localhost

# Start frontend
npm start
```

### 2. Understanding Arbitrage Opportunities
The test environment creates realistic price differences:
- **Mock Uniswap**: 5% worse exchange rates (buy opportunity)
- **Mock SushiSwap**: 5% better exchange rates (sell opportunity)
- **Your AMM**: Baseline 1:1 ratio for comparison

### 3. Monitoring Profits
- Check console output for arbitrage execution results
- Monitor gas costs vs profit margins
- Analyze successful vs failed arbitrage attempts

## Production Deployment

### Mainnet Considerations
- **Gas Optimization**: Critical for profitable arbitrage
- **MEV Protection**: Consider flashbots integration
- **Liquidity Requirements**: Ensure sufficient AMM liquidity
- **Risk Management**: Implement slippage protection and maximum loss limits

### Security Audits
- **Reentrancy Protection**: All external calls protected
- **Access Controls**: Owner-only functions properly secured
- **Integer Overflow**: Safe math operations throughout
- **Flashloan Security**: Proper repayment validation

## License

ISC
