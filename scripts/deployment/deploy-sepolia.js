// Sepolia Deployment Script with Enhanced Logging and Verification
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("\n🚀 Starting Sepolia Deployment...\n");
  
  const [deployer] = await hre.ethers.getSigners();
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  
  console.log("📋 Deployment Details:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`Network: ${hre.network.name}`);
  console.log(`Chain ID: ${(await hre.ethers.provider.getNetwork()).chainId}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${hre.ethers.formatEther(balance)} ETH`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Check balance
  if (balance < hre.ethers.parseEther("0.1")) {
    console.warn("⚠️  WARNING: Low balance! You may need more ETH for deployment.");
    console.warn("   Get Sepolia ETH from: https://sepoliafaucet.com/\n");
  }

  const deployedContracts = {};

  // Deploy Token 1 (DAPP)
  console.log("📦 Deploying DAPP Token...");
  const Token = await hre.ethers.getContractFactory('Token');
  const dapp = await Token.deploy('Dapp Token', 'DAPP', '1000000');
  await dapp.waitForDeployment();
  const dappAddress = await dapp.getAddress();
  deployedContracts.dapp = dappAddress;
  console.log(`✅ DAPP Token deployed to: ${dappAddress}\n`);

  // Deploy Token 2 (USD)
  console.log("📦 Deploying USD Token...");
  const usd = await Token.deploy('USD Token', 'USD', '1000000');
  await usd.waitForDeployment();
  const usdAddress = await usd.getAddress();
  deployedContracts.usd = usdAddress;
  console.log(`✅ USD Token deployed to: ${usdAddress}\n`);

  // Deploy AMM
  console.log("📦 Deploying AMM Contract...");
  const AMM = await hre.ethers.getContractFactory('AutomatedMarketMaker');
  const amm = await AMM.deploy(dappAddress, usdAddress);
  await amm.waitForDeployment();
  const ammAddress = await amm.getAddress();
  deployedContracts.amm = ammAddress;
  console.log(`✅ AMM deployed to: ${ammAddress}\n`);

  // Deploy Price Oracle
  console.log("📦 Deploying Price Oracle...");
  const PriceOracle = await hre.ethers.getContractFactory('PriceOracle');
  const oracle = await PriceOracle.deploy();
  await oracle.waitForDeployment();
  const oracleAddress = await oracle.getAddress();
  deployedContracts.oracle = oracleAddress;
  console.log(`✅ Price Oracle deployed to: ${oracleAddress}\n`);

  // Deploy FlashLoanHub
  console.log("📦 Deploying FlashLoan Hub...");
  const FlashLoanHub = await hre.ethers.getContractFactory('FlashLoanHub');
  const flashLoanHub = await FlashLoanHub.deploy();
  await flashLoanHub.waitForDeployment();
  const flashLoanHubAddress = await flashLoanHub.getAddress();
  deployedContracts.flashLoanHub = flashLoanHubAddress;
  console.log(`✅ FlashLoan Hub deployed to: ${flashLoanHubAddress}\n`);

  // Deploy SimpleArbitrage Strategy
  console.log("📦 Deploying SimpleArbitrage Strategy...");
  const SimpleArbitrage = await hre.ethers.getContractFactory('SimpleArbitrage');
  const simpleArb = await SimpleArbitrage.deploy(flashLoanHubAddress);
  await simpleArb.waitForDeployment();
  const simpleArbAddress = await simpleArb.getAddress();
  deployedContracts.simpleArbitrage = simpleArbAddress;
  console.log(`✅ SimpleArbitrage deployed to: ${simpleArbAddress}\n`);

  // Deploy TriangularArbitrage Strategy
  console.log("📦 Deploying TriangularArbitrage Strategy...");
  const TriangularArbitrage = await hre.ethers.getContractFactory('TriangularArbitrage');
  const triangularArb = await TriangularArbitrage.deploy(flashLoanHubAddress);
  await triangularArb.waitForDeployment();
  const triangularArbAddress = await triangularArb.getAddress();
  deployedContracts.triangularArbitrage = triangularArbAddress;
  console.log(`✅ TriangularArbitrage deployed to: ${triangularArbAddress}\n`);

  // Summary
  console.log("\n🎉 Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`DAPP Token:           ${dappAddress}`);
  console.log(`USD Token:            ${usdAddress}`);
  console.log(`AMM:                  ${ammAddress}`);
  console.log(`Price Oracle:         ${oracleAddress}`);
  console.log(`FlashLoan Hub:        ${flashLoanHubAddress}`);
  console.log(`SimpleArbitrage:      ${simpleArbAddress}`);
  console.log(`TriangularArbitrage:  ${triangularArbAddress}`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Update config.json
  const chainId = (await hre.ethers.provider.getNetwork()).chainId.toString();
  const configPath = path.join(__dirname, '../src/config.json');
  let config = {};
  
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }

  config[chainId] = {
    dapp: { address: dappAddress },
    usd: { address: usdAddress },
    amm: { address: ammAddress },
    oracle: { address: oracleAddress },
    flashLoanHub: { address: flashLoanHubAddress },
    simpleArbitrage: { address: simpleArbAddress },
    triangularArbitrage: { address: triangularArbAddress }
  };

  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  console.log(`✅ Updated config.json with Sepolia addresses (Chain ID: ${chainId})\n`);

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: deployedContracts
  };

  const deploymentsDir = path.join(__dirname, '../deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const deploymentFile = path.join(deploymentsDir, `sepolia-${Date.now()}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log(`✅ Deployment info saved to: ${deploymentFile}\n`);

  // Verification instructions
  if (process.env.ETHERSCAN_API_KEY) {
    console.log("🔍 To verify contracts on Etherscan, run:");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log(`npx hardhat verify --network sepolia ${dappAddress} "Dapp Token" "DAPP" "1000000"`);
    console.log(`npx hardhat verify --network sepolia ${usdAddress} "USD Token" "USD" "1000000"`);
    console.log(`npx hardhat verify --network sepolia ${ammAddress} ${dappAddress} ${usdAddress}`);
    console.log(`npx hardhat verify --network sepolia ${oracleAddress}`);
    console.log(`npx hardhat verify --network sepolia ${flashLoanHubAddress}`);
    console.log(`npx hardhat verify --network sepolia ${simpleArbAddress} ${flashLoanHubAddress}`);
    console.log(`npx hardhat verify --network sepolia ${triangularArbAddress} ${flashLoanHubAddress}`);
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  }

  console.log("📝 Next Steps:");
  console.log("1. Verify contracts on Etherscan (see commands above)");
  console.log("2. Update .env with contract addresses");
  console.log("3. Approve strategies in FlashLoanHub");
  console.log("4. Add initial liquidity to AMM");
  console.log("5. Deploy frontend to Vercel\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

