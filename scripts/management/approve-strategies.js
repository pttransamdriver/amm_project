// Script to approve arbitrage strategies in FlashLoanHub
const hre = require("hardhat");
const config = require("../../src/config.json");

async function main() {
  console.log("\n🔐 Approving Arbitrage Strategies...\n");

  const [deployer] = await hre.ethers.getSigners();
  const chainId = (await hre.ethers.provider.getNetwork()).chainId.toString();

  console.log("📋 Details:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`Network: ${hre.network.name}`);
  console.log(`Chain ID: ${chainId}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Check if config exists for this network
  if (!config[chainId]) {
    console.error(`❌ No configuration found for chain ID ${chainId}`);
    console.error("Please deploy contracts first using deploy-sepolia.js");
    process.exit(1);
  }

  const networkConfig = config[chainId];

  // Get FlashLoanHub contract
  const flashLoanHubAddress = networkConfig.flashLoanHub?.address;
  if (!flashLoanHubAddress) {
    console.error("❌ FlashLoanHub address not found in config");
    process.exit(1);
  }

  console.log(`📦 FlashLoanHub: ${flashLoanHubAddress}\n`);

  const FlashLoanHub = await hre.ethers.getContractFactory("FlashLoanHub");
  const flashLoanHub = FlashLoanHub.attach(flashLoanHubAddress);

  // Get strategy addresses
  const simpleArbAddress = networkConfig.simpleArbitrage?.address;
  const triangularArbAddress = networkConfig.triangularArbitrage?.address;

  if (!simpleArbAddress || !triangularArbAddress) {
    console.error("❌ Strategy addresses not found in config");
    process.exit(1);
  }

  console.log("🎯 Strategies to approve:");
  console.log(`  - SimpleArbitrage: ${simpleArbAddress}`);
  console.log(`  - TriangularArbitrage: ${triangularArbAddress}\n`);

  // Check current approval status
  console.log("🔍 Checking current approval status...");
  const simpleArbApproved = await flashLoanHub.isStrategyApproved(simpleArbAddress);
  const triangularArbApproved = await flashLoanHub.isStrategyApproved(triangularArbAddress);

  console.log(`  SimpleArbitrage: ${simpleArbApproved ? '✅ Already approved' : '❌ Not approved'}`);
  console.log(`  TriangularArbitrage: ${triangularArbApproved ? '✅ Already approved' : '❌ Not approved'}\n`);

  // Approve strategies if not already approved
  const strategiesToApprove = [];
  if (!simpleArbApproved) strategiesToApprove.push(simpleArbAddress);
  if (!triangularArbApproved) strategiesToApprove.push(triangularArbAddress);

  if (strategiesToApprove.length === 0) {
    console.log("✅ All strategies are already approved!\n");
    return;
  }

  console.log(`📝 Approving ${strategiesToApprove.length} strategy(ies)...\n`);

  // Batch approve for gas efficiency
  try {
    const tx = await flashLoanHub.batchApproveStrategies(strategiesToApprove);
    console.log(`⏳ Transaction submitted: ${tx.hash}`);
    console.log("   Waiting for confirmation...");
    
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}\n`);

    // Verify approval
    console.log("🔍 Verifying approval status...");
    for (const strategy of strategiesToApprove) {
      const isApproved = await flashLoanHub.isStrategyApproved(strategy);
      const strategyName = strategy === simpleArbAddress ? "SimpleArbitrage" : "TriangularArbitrage";
      console.log(`  ${strategyName}: ${isApproved ? '✅ Approved' : '❌ Failed'}`);
    }

    console.log("\n🎉 Strategy approval complete!\n");

    console.log("📝 Next Steps:");
    console.log("1. Strategies can now execute flashloans");
    console.log("2. Add initial liquidity to AMM");
    console.log("3. Test arbitrage functionality");
    console.log("4. Monitor for profitable opportunities\n");

  } catch (error) {
    console.error("\n❌ Error approving strategies:");
    console.error(error.message);
    
    if (error.message.includes("Ownable: caller is not the owner")) {
      console.error("\n⚠️  You are not the owner of the FlashLoanHub contract");
      console.error("   Only the contract owner can approve strategies");
    }
    
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

