const hre = require("hardhat");

async function main() {
  const { ethers } = hre;
  const [deployer] = await ethers.getSigners();
  
  // Replace with actual deployed addresses from deploy-test.js output
  const DAPP_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Update this
  const USD_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";   // Update this
  const AMM_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";   // Update this
  const MOCK_UNI_QUOTER = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"; // Update this
  const MOCK_SUSHI_ROUTER = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"; // Update this

  // Get contract instances
  const dapp = await ethers.getContractAt('Token', DAPP_ADDRESS);
  const usd = await ethers.getContractAt('Token', USD_ADDRESS);
  const amm = await ethers.getContractAt('AutomatedMarketMaker', AMM_ADDRESS);
  const mockUniQuoter = await ethers.getContractAt('MockUniswapV3Quoter', MOCK_UNI_QUOTER);
  const mockSushiRouter = await ethers.getContractAt('MockSushiSwapRouter', MOCK_SUSHI_ROUTER);
 
  console.log("Testing arbitrage opportunities...\n");

  // Add liquidity to AMM (1:1 ratio)
  const liquidityAmount = ethers.parseUnits('1000', 'ether');
  await dapp.approve(AMM_ADDRESS, liquidityAmount);
  await usd.approve(AMM_ADDRESS, liquidityAmount);
  await amm.addLiquidity(liquidityAmount, liquidityAmount);
  console.log("Added liquidity to AMM");

  // Test prices
  const testAmount = ethers.parseUnits('100', 'ether');
  
  // AMM price (should be close to 1:1)
  const ammPrice = await amm.calculateFirstTokenSwap(testAmount);
  console.log(`AMM price: 100 DAPP = ${ethers.formatUnits(ammPrice, 'ether')} USD`);

  // Mock Uniswap price via quoter (worse rate: ~95)
  const uniPrice = await mockUniQuoter.quoteExactInputSingle(
    DAPP_ADDRESS,
    USD_ADDRESS,
    3000,
    testAmount,
    0
  );
  console.log(`Uniswap price: 100 DAPP = ${ethers.formatUnits(uniPrice, 'ether')} USD`);

  // Mock SushiSwap price (better rate: ~105)
  const sushiAmounts = await mockSushiRouter.getAmountsOut(testAmount, [DAPP_ADDRESS, USD_ADDRESS]);
  console.log(`SushiSwap price: 100 DAPP = ${ethers.formatUnits(sushiAmounts[1], 'ether')} USD`);

  console.log("\nArbitrage opportunity detected!");
  console.log("Strategy: Buy from Uniswap (cheaper), sell on SushiSwap (higher price)");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});