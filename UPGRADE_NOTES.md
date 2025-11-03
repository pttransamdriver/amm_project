# Project Upgrade Notes

## Summary of Changes

This document outlines all the changes made to upgrade the project dependencies and fix security vulnerabilities.

## 1. Dependencies Updated

### Frontend Dependencies
- **ethers.js**: Upgraded from v5 to v6.14.4 (latest)
- **react**: Already at 18.3.1 (latest stable)
- **react-dom**: Already at 18.3.1
- **@reduxjs/toolkit**: Already at 2.8.1
- **@testing-library/react**: Upgraded to 16.1.0
- **@testing-library/jest-dom**: Upgraded to 6.6.3
- **react-apexcharts**: Upgraded to 1.6.0
- **apexcharts**: Added 3.54.1 (peer dependency)
- **react-bootstrap**: Upgraded to 2.10.7
- **react-router-dom**: Upgraded to 7.1.1
- **react-router-bootstrap**: Upgraded to 0.26.3
- **web-vitals**: Upgraded to 4.2.4
- **dotenv**: Added 16.4.7 for environment variable support

### Development Dependencies
- **hardhat**: Upgraded to 2.22.18
- **@nomicfoundation/hardhat-toolbox**: Upgraded to 5.0.0
- **@nomicfoundation/hardhat-ethers**: Added 3.0.8
- **@nomicfoundation/hardhat-chai-matchers**: Added 2.0.8
- **@nomicfoundation/hardhat-verify**: Added 2.0.11
- **hardhat-gas-reporter**: Added 2.2.1
- **solidity-coverage**: Added 0.8.14
- **chai**: Added 4.5.0
- **typechain**: Added 8.3.2

## 2. Environment Variables Configuration

### New Files Created
- `.env.example`: Template file with all required environment variables

### Environment Variables Added
```
# Network Configuration
LOCALHOST_RPC_URL=http://127.0.0.1:8545
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY

# Private Keys (NEVER commit real keys!)
PRIVATE_KEY=your_private_key_here

# API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here

# Gas Reporter
REPORT_GAS=false

# Contract Addresses (populated after deployment)
LOCALHOST_DAPP_TOKEN_ADDRESS=
LOCALHOST_USD_TOKEN_ADDRESS=
LOCALHOST_AMM_ADDRESS=
```

## 3. Hardhat Configuration Updates

### hardhat.config.js Changes
- Added `dotenv` configuration
- Added network configurations (localhost, sepolia, mainnet)
- Added Etherscan verification support
- Added gas reporter configuration
- Added compiler optimization settings
- All sensitive data now loaded from environment variables

## 4. Ethers.js v5 to v6 Migration

### Breaking Changes Fixed

#### Provider Changes
```javascript
// OLD (v5)
const provider = new ethers.providers.Web3Provider(window.ethereum)

// NEW (v6)
const provider = new ethers.BrowserProvider(window.ethereum)
```

#### Utility Functions
```javascript
// OLD (v5)
ethers.utils.parseUnits()
ethers.utils.formatUnits()
ethers.utils.getAddress()

// NEW (v6)
ethers.parseUnits()
ethers.formatUnits()
ethers.getAddress()
```

#### Contract Deployment
```javascript
// OLD (v5)
await contract.deployed()
console.log(contract.address)

// NEW (v6)
await contract.waitForDeployment()
console.log(await contract.getAddress())
```

#### Network Information
```javascript
// OLD (v5)
const { chainId } = await provider.getNetwork()

// NEW (v6)
const network = await provider.getNetwork()
const chainId = Number(network.chainId)
```

#### Zero Address
```javascript
// OLD (v5)
expect(address).to.not.equal(0x0)

// NEW (v6)
expect(address).to.not.equal(ethers.ZeroAddress)
```

## 5. Files Modified

### Configuration Files
- `package.json` - Updated all dependencies
- `hardhat.config.js` - Added environment variable support and network configs
- `.gitignore` - Cleaned up duplicates, added more patterns

### Source Files (Frontend)
- `src/store/interactions.js` - Updated to ethers v6 syntax
- `src/components/Deposit.js` - Updated to ethers v6 syntax
- `src/components/Withdraw.js` - Updated to ethers v6 syntax
- `src/components/Swap.js` - Updated to ethers v6 syntax

### Script Files
- `scripts/deploy.js` - Updated to ethers v6 syntax
- `scripts/seed.js` - Updated to ethers v6 syntax

### Test Files
- `test/Token.js` - ✅ Fully updated to ethers v6 syntax
- `test/AMM.js` - ✅ Fully updated to ethers v6 syntax

All ethers v5 syntax has been successfully migrated to v6:
- ✅ `ethers.utils.formatEther` → `ethers.formatEther`
- ✅ `ethers.utils.formatUnits` → `ethers.formatUnits`
- ✅ `ethers.utils.parseUnits` → `ethers.parseUnits`
- ✅ `ethers.utils.getAddress` → `ethers.getAddress`
- ✅ `ethers.providers.Web3Provider` → `ethers.BrowserProvider`
- ✅ `contract.deployed()` → `await contract.waitForDeployment()`
- ✅ `contract.address` → `await contract.getAddress()` (for contracts only)
- ✅ `0x0` → `ethers.ZeroAddress`

## 6. Security Improvements

1. **No Hardcoded Keys**: All sensitive data moved to environment variables
2. **Updated Dependencies**: All packages updated to latest secure versions
3. **Better .gitignore**: Prevents accidental commit of sensitive files
4. **Environment Template**: `.env.example` provides clear guidance

## 7. Next Steps

### Before Running the Project

1. **Install Dependencies**:
   ```bash
   cd amm_project
   npm install
   ```

2. **Create .env File**:
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

3. **Compile Contracts**:
   ```bash
   npx hardhat compile
   ```

4. **Run Tests**:
   ```bash
   npx hardhat test
   ```

5. **Start Local Node**:
   ```bash
   npx hardhat node
   ```

6. **Deploy Contracts** (in another terminal):
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

7. **Seed Data** (optional):
   ```bash
   npx hardhat run scripts/seed.js --network localhost
   ```

8. **Start Frontend**:
   ```bash
   npm start
   ```

### Testing on Testnets

1. Get testnet ETH from faucets:
   - Sepolia: https://sepoliafaucet.com/

2. Update `.env` with your:
   - Sepolia RPC URL (from Alchemy or Infura)
   - Private key (from MetaMask - export private key)
   - Etherscan API key (for verification)

3. Deploy to Sepolia:
   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```

4. Verify contracts:
   ```bash
   npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS "Constructor" "Args"
   ```

## 8. Testing Recommendations

1. **Run Tests**: After installing dependencies, run the test suite to verify all changes:
   ```bash
   npx hardhat test
   ```

2. **React Router**: Upgraded to v7 which may have breaking changes. Test all routing functionality thoroughly.

3. **Contract Addresses**: After deployment, update `src/config.json` with the new contract addresses, or better yet, load them from environment variables.

4. **Frontend Testing**: Test all frontend components (Swap, Deposit, Withdraw) to ensure ethers v6 integration works correctly.

## 9. Security Reminders

- **NEVER** commit your `.env` file
- **NEVER** use your mainnet private key for testing
- **ALWAYS** use a separate wallet for development
- **ALWAYS** test on testnets before mainnet deployment
- **NEVER** share your private keys or API keys
- Use Hardhat's default test accounts for local development

## 10. Additional Resources

- [Ethers.js v6 Migration Guide](https://docs.ethers.org/v6/migrating/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [React 18 Documentation](https://react.dev/)
- [Sepolia Testnet](https://sepolia.dev/)

