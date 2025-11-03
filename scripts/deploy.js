// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const Token = await hre.ethers.getContractFactory('Token')

  // Deploy Token 1
  let dapp = await Token.deploy('Dapp Token', 'DAPP', '1000000') // 1 million tokens
  await dapp.waitForDeployment()
  console.log(`Dapp Token deployed to: ${await dapp.getAddress()}\n`)

  // Deploy Token 2
  const usd = await Token.deploy('USD Token', 'USD', '1000000') // 1 million tokens
  await usd.waitForDeployment()
  console.log(`USD Token deployed to: ${await usd.getAddress()}\n`)

  // Deploy AMM
  const AMM = await hre.ethers.getContractFactory('AutomatedMarketMaker')
  const amm = await AMM.deploy(await dapp.getAddress(), await usd.getAddress())
  await amm.waitForDeployment()
  console.log(`AMM contract deployed to: ${await amm.getAddress()}\n`)

  // Deploy Price Oracle
  const PriceOracle = await hre.ethers.getContractFactory('PriceOracle')
  const oracle = await PriceOracle.deploy()
  await oracle.waitForDeployment()
  console.log(`Price Oracle deployed to: ${await oracle.getAddress()}\n`)

  // Deploy Flash Arbitrage
  const FlashArbitrage = await hre.ethers.getContractFactory('FlashArbitrage')
  const flashArb = await FlashArbitrage.deploy(await amm.getAddress())
  await flashArb.waitForDeployment()
  console.log(`Flash Arbitrage deployed to: ${await flashArb.getAddress()}\n`)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
