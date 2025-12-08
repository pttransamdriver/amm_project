const hre = require("hardhat");

async function main() {
  const { ethers } = hre;
  const [deployer] = await ethers.getSigners();
  console.log("Deploying test environment with account:", deployer.address);

  // Deploy tokens
  const Token = await hre.ethers.getContractFactory('Token');
  const dapp = await Token.deploy('Dapp Token', 'DAPP', '1000000');
  await dapp.waitForDeployment();
  console.log(`Dapp Token deployed to: ${await dapp.getAddress()}`);

  const usd = await Token.deploy('USD Token', 'USD', '1000000');
  await usd.waitForDeployment();
  console.log(`USD Token deployed to: ${await usd.getAddress()}`);

  // Deploy AMM
  const AMM = await hre.ethers.getContractFactory('AutomatedMarketMaker');
  const amm = await AMM.deploy(await dapp.getAddress(), await usd.getAddress());
  await amm.waitForDeployment();
  console.log(`AMM deployed to: ${await amm.getAddress()}`);

  // Deploy Mock DEXs
  const MockUniRouter = await hre.ethers.getContractFactory('MockUniswapV3Router');
  const mockUniRouter = await MockUniRouter.deploy();
  await mockUniRouter.waitForDeployment();
  console.log(`Mock Uniswap Router deployed to: ${await mockUniRouter.getAddress()}`);

  const MockUniQuoter = await hre.ethers.getContractFactory('MockUniswapV3Quoter');
  const mockUniQuoter = await MockUniQuoter.deploy();
  await mockUniQuoter.waitForDeployment();
  console.log(`Mock Uniswap Quoter deployed to: ${await mockUniQuoter.getAddress()}`);

  const MockSushiRouter = await hre.ethers.getContractFactory('MockSushiSwapRouter');
  const mockSushiRouter = await MockSushiRouter.deploy();
  await mockSushiRouter.waitForDeployment();
  console.log(`Mock SushiSwap Router deployed to: ${await mockSushiRouter.getAddress()}`);

  // Fund mock DEXs with tokens for trading
  const fundAmount = ethers.parseUnits('100000', 'ether');
  await dapp.transfer(await mockUniRouter.getAddress(), fundAmount);
  await usd.transfer(await mockUniRouter.getAddress(), fundAmount);
  await dapp.transfer(await mockSushiRouter.getAddress(), fundAmount);
  await usd.transfer(await mockSushiRouter.getAddress(), fundAmount);

  console.log("Mock DEXs funded with tokens");

  // Save addresses for testing
  const addresses = {
    dapp: await dapp.getAddress(),
    usd: await usd.getAddress(),
    amm: await amm.getAddress(),
    mockUniRouter: await mockUniRouter.getAddress(),
    mockUniQuoter: await mockUniQuoter.getAddress(),
    mockSushiRouter: await mockSushiRouter.getAddress()
  };

  console.log("\nDeployment complete!");
  console.log("Addresses:", addresses);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});