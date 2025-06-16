// Import required testing libraries and utilities
const { expect } = require('chai'); // Chai is the assertion library used for testing - it provides functions like expect() to check if values match expected results
const { ethers } = require('hardhat'); // Ethers.js is the library used to interact with Ethereum blockchain and smart contracts

// Helper function to convert numbers to wei (smallest unit of ether)
const tokens = (n) => {
  return ethers.utils.parseUnits(n.toString(), 'ether') // Converts a number to wei format (18 decimals). For example, tokens(1) = 1000000000000000000 wei = 1 ether
}

// Create aliases for the tokens function to make code more readable
const ether = tokens // "ether" is an alias for "tokens" - both do the same thing
const shares = ether // "shares" is also an alias for "tokens" - used when dealing with liquidity pool shares

// Main test suite for the AMM (Automated Market Maker) contract
describe('AMM', () => {
  // Declare variables to hold account addresses and contract instances
  let accounts, // Array of all available test accounts
      deployer, // Account that deploys the contracts (usually accounts[0])
      liquidityProvider, // Account that provides liquidity to the pool (accounts[1])
      investor1, // First investor account for testing swaps (accounts[2])
      investor2 // Second investor account for testing swaps (accounts[3])

  let token1, // Instance of the first token contract (firstToken in AMM)
      token2, // Instance of the second token contract (secondToken in AMM)
      amm // Instance of the AMM contract

  // beforeEach runs before every individual test case - sets up the testing environment
  beforeEach(async () => {
    // Setup Accounts - Get test accounts from Hardhat's local blockchain
    accounts = await ethers.getSigners() // Gets an array of 20 test accounts with ETH balances
    deployer = accounts[0] // First account - deploys contracts and has initial token supply
    liquidityProvider = accounts[1] // Second account - will provide liquidity to the AMM pool
    investor1 = accounts[2] // Third account - will test swapping firstToken for secondToken
    investor2 = accounts[3] // Fourth account - will test swapping secondToken for firstToken

    // Deploy Token Contracts - Create two separate ERC-20 tokens for the AMM pool
    const Token = await ethers.getContractFactory('Token') // Get the Token contract factory for deployment
    token1 = await Token.deploy('Dapp University', 'DAPP', '1000000') // Deploy first token: name="Dapp University", symbol="DAPP", totalSupply=1,000,000 tokens
    token2 = await Token.deploy('USD Token', 'USD', '1000000') // Deploy second token: name="USD Token", symbol="USD", totalSupply=1,000,000 tokens

    // Distribute tokens to test accounts for testing purposes
    // Send tokens to liquidity provider (100,000 of each token)
    let transaction = await token1.connect(deployer).transfer(liquidityProvider.address, tokens(100000)) // Transfer 100,000 DAPP tokens from deployer to liquidityProvider
    await transaction.wait() // Wait for the transaction to be mined on the blockchain

    transaction = await token2.connect(deployer).transfer(liquidityProvider.address, tokens(100000)) // Transfer 100,000 USD tokens from deployer to liquidityProvider
    await transaction.wait() // Wait for the transaction to be mined

    // Send token1 to investor1 (100,000 DAPP tokens for swapping)
    transaction = await token1.connect(deployer).transfer(investor1.address, tokens(100000)) // Transfer 100,000 DAPP tokens to investor1
    await transaction.wait() // Wait for transaction confirmation

    // Send token2 to investor2 (100,000 USD tokens for swapping)
    transaction = await token2.connect(deployer).transfer(investor2.address, tokens(100000)) // Transfer 100,000 USD tokens to investor2
    await transaction.wait() // Wait for transaction confirmation

    // Deploy AMM Contract - Create the Automated Market Maker with the two tokens
    const AMM = await ethers.getContractFactory('AutomatedMarketMaker') // Get the AMM contract factory (note: contract name is 'AutomatedMarketMaker')
    amm = await AMM.deploy(token1.address, token2.address) // Deploy AMM with addresses of the two tokens as constructor parameters
  })

  // Test suite for contract deployment verification
  describe('Deployment', () => {

    // Test 1: Verify that the AMM contract was deployed successfully and has a valid address
    it('has an address', async () => {
      expect(amm.address).to.not.equal(0x0) // Check that the contract address is not the zero address (0x0000...0000)
    })

    // Test 2: Verify that the AMM contract correctly stores the first token address
    it('tracks firstToken address', async () => {
      expect(await amm.firstToken()).to.equal(token1.address) // Check that the firstToken state variable matches the deployed token1 address
    })

    // Test 3: Verify that the AMM contract correctly stores the second token address
    it('tracks secondToken address', async () => {
      expect(await amm.secondToken()).to.equal(token2.address) // Check that the secondToken state variable matches the deployed token2 address
    })

  })

  // Test suite for token swapping functionality
  describe('Swapping tokens', () => {
    let amount, transaction, estimate, balance // Declare variables used throughout the swapping tests

    it('facilitates swaps', async () => {
      // STEP 1: INITIAL LIQUIDITY PROVISION
      // Deployer approves 100k tokens for the AMM contract to spend
      amount = tokens(100000) // Set amount to 100,000 tokens (in wei format)
      transaction = await token1.connect(deployer).approve(amm.address, amount) // Approve AMM to spend 100k DAPP tokens from deployer
      await transaction.wait() // Wait for approval transaction to be mined

      transaction = await token2.connect(deployer).approve(amm.address, amount) // Approve AMM to spend 100k USD tokens from deployer
      await transaction.wait() // Wait for approval transaction to be mined

      // Deployer adds initial liquidity to the pool (100k of each token)
      transaction = await amm.connect(deployer).addLiquidity(amount, amount) // Call addLiquidity function with equal amounts of both tokens
      await transaction.wait() // Wait for addLiquidity transaction to be mined

      // STEP 2: VERIFY INITIAL LIQUIDITY PROVISION
      // Check that the AMM contract received the tokens
      expect(await token1.balanceOf(amm.address)).to.equal(amount) // Verify AMM contract holds 100k DAPP tokens
      expect(await token2.balanceOf(amm.address)).to.equal(amount) // Verify AMM contract holds 100k USD tokens

      // Check that the AMM's internal accounting matches the actual token balances
      expect(await amm.firstTokenReserve()).to.equal(amount) // Verify firstTokenReserve state variable equals 100k
      expect(await amm.secondTokenReserve()).to.equal(amount) // Verify secondTokenReserve state variable equals 100k

      // Check deployer received the correct amount of liquidity shares
      expect(await amm.userLiquidityShares(deployer.address)).to.equal(tokens(100)) // Deployer should have 100 shares (100 * 10^18 in wei)

      // Check total shares in the pool
      expect(await amm.totalSharesCirculating()).to.equal(tokens(100)) // Total pool shares should be 100 (100 * 10^18 in wei)



      /////////////////////////////////////////////////////////////
      // STEP 3: LIQUIDITY PROVIDER ADDS MORE LIQUIDITY
      /////////////////////////////////////////////////////////////

      // LP (Liquidity Provider) approves 50k tokens for the AMM to spend
      amount = tokens(50000) // Set amount to 50,000 tokens
      transaction = await token1.connect(liquidityProvider).approve(amm.address, amount) // LP approves AMM to spend 50k DAPP tokens
      await transaction.wait() // Wait for approval transaction

      transaction = await token2.connect(liquidityProvider).approve(amm.address, amount) // LP approves AMM to spend 50k USD tokens
      await transaction.wait() // Wait for approval transaction

      // Calculate the required amount of secondToken to maintain pool ratio
      let secondTokenDeposit = await amm.calculateFirstTokenDeposit(amount) // Calculate how much USD token is needed for 50k DAPP tokens to maintain 1:1 ratio

      // LP adds liquidity to the pool with the calculated amounts
      transaction = await amm.connect(liquidityProvider).addLiquidity(amount, secondTokenDeposit) // Add liquidity with proper ratio
      await transaction.wait() // Wait for addLiquidity transaction

      // STEP 4: VERIFY SECOND LIQUIDITY PROVISION
      // LP should have 50 shares (50% of the deployer's initial 100k deposit)
      expect(await amm.userLiquidityShares(liquidityProvider.address)).to.equal(tokens(50)) // LP gets 50 shares for adding 50% of existing liquidity

      // Deployer should still have 100 shares (unchanged)
      expect(await amm.userLiquidityShares(deployer.address)).to.equal(tokens(100)) // Deployer's shares remain the same

      // Pool should have 150 total shares (100 + 50)
      expect(await amm.totalSharesCirculating()).to.equal(tokens(150)) // Total shares = deployer's 100 + LP's 50


      /////////////////////////////////////////////////////////////
      // STEP 5: INVESTOR 1 PERFORMS FIRST TOKEN SWAP
      /////////////////////////////////////////////////////////////

      // Check and log the current price ratio before swapping
      console.log(`Price: ${await amm.secondTokenReserve() / await amm.firstTokenReserve()} \n`) // Price = secondToken/firstToken ratio

      // Investor1 approves the AMM to spend their tokens for swapping
      transaction = await token1.connect(investor1).approve(amm.address, tokens(100000)) // Approve AMM to spend up to 100k DAPP tokens
      await transaction.wait() // Wait for approval transaction

      // Check and log investor1's secondToken balance before the swap
      balance = await token2.balanceOf(investor1.address) // Get investor1's current USD token balance
      console.log(`Investor1 Token2 balance before swap: ${ethers.utils.formatEther(balance)}\n`) // Log balance in human-readable format

      // Calculate how many secondTokens investor1 will receive for swapping 1 firstToken
      estimate = await amm.calculateFirstTokenSwap(tokens(1)) // Calculate output amount including 0.3% fee and slippage
      console.log(`Token2 amount investor1 will receive after swap: ${ethers.utils.formatEther(estimate)}\n`) // Log expected output

      // Investor1 executes the swap: 1 DAPP token for USD tokens
      transaction = await amm.connect(investor1).swapFirstToken(tokens(1)) // Call swapFirstToken function with 1 DAPP token
      await transaction.wait() // Wait for swap transaction to be mined

      // Verify that the Swap event was emitted with correct parameters
      await expect(transaction).to.emit(amm, 'Swap') // Check that 'Swap' event was emitted
        .withArgs(
          investor1.address, // user who performed the swap
          await amm.firstToken(), // address of token swapped (DAPP token)
          tokens(1), // amount swapped (1 DAPP token)
          await amm.secondToken(), // address of token received (USD token)
          estimate, // amount received (calculated estimate)
          await amm.firstTokenReserve(), // new firstToken reserve after swap
          await amm.secondTokenReserve(), // new secondToken reserve after swap
          (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp // timestamp of the block
        )

      // STEP 6: VERIFY FIRST SWAP RESULTS
      // Check and log investor1's secondToken balance after the swap
      balance = await token2.balanceOf(investor1.address) // Get investor1's new USD token balance
      console.log(`Investor1 Token2 balance after swap: ${ethers.utils.formatEther(balance)}\n`) // Log new balance
      expect(estimate).to.equal(balance) // Verify that the actual received amount matches the calculated estimate

      // Verify that AMM's internal accounting matches actual token balances
      expect(await token1.balanceOf(amm.address)).to.equal(await amm.firstTokenReserve()) // AMM's DAPP token balance should match firstTokenReserve
      expect(await token2.balanceOf(amm.address)).to.equal(await amm.secondTokenReserve()) // AMM's USD token balance should match secondTokenReserve

      // Check and log the new price ratio after the swap
      console.log(`Price: ${await amm.secondTokenReserve() / await amm.firstTokenReserve()} \n`) // Price should have changed due to the swap


      /////////////////////////////////////////////////////////////
      // STEP 7: INVESTOR 1 SWAPS AGAIN (TESTING PRICE IMPACT)
      /////////////////////////////////////////////////////////////

      // Test another swap to demonstrate how repeated swaps affect price and slippage
      balance = await token2.balanceOf(investor1.address) // Get current USD token balance
      console.log(`Investor1 Token2 balance before swap: ${ethers.utils.formatEther(balance)}`) // Log balance before second swap

      // Calculate expected output for another 1 DAPP token swap (price should be different now)
      estimate = await amm.calculateFirstTokenSwap(tokens(1)) // Calculate output with current pool state
      console.log(`Token2 Amount investor1 will receive after swap: ${ethers.utils.formatEther(estimate)}`) // Log expected output (should be less than first swap)

      // Execute the second swap of 1 DAPP token
      transaction = await amm.connect(investor1).swapFirstToken(tokens(1)) // Swap another 1 DAPP token
      await transaction.wait() // Wait for transaction

      // Check and log investor1's balance after the second swap
      balance = await token2.balanceOf(investor1.address) // Get new USD token balance
      console.log(`Investor1 Token2 balance after swap: ${ethers.utils.formatEther(balance)} \n`) // Log new balance

      // Verify AMM's internal accounting remains accurate
      expect(await token1.balanceOf(amm.address)).to.equal(await amm.firstTokenReserve()) // Check DAPP token balance consistency
      expect(await token2.balanceOf(amm.address)).to.equal(await amm.secondTokenReserve()) // Check USD token balance consistency

      // Check and log the price after the second swap (should show further price movement)
      console.log(`Price: ${await amm.secondTokenReserve() / await amm.firstTokenReserve()} \n`) // Price continues to change with each swap

      /////////////////////////////////////////////////////////////
      // STEP 8: INVESTOR 1 SWAPS A LARGE AMOUNT (TESTING HIGH SLIPPAGE)
      /////////////////////////////////////////////////////////////

      // Test a large swap to demonstrate significant price impact and slippage
      balance = await token2.balanceOf(investor1.address) // Get current USD token balance
      console.log(`Investor1 Token2 balance before swap: ${ethers.utils.formatEther(balance)}`) // Log balance before large swap

      // Calculate expected output for a large 100 DAPP token swap (will show significant slippage)
      estimate = await amm.calculateFirstTokenSwap(tokens(100)) // Calculate output for 100 DAPP tokens
      console.log(`Token2 Amount investor1 will receive after swap: ${ethers.utils.formatEther(estimate)}`) // Log expected output (much less than 100 due to slippage)

      // Execute the large swap of 100 DAPP tokens
      transaction = await amm.connect(investor1).swapFirstToken(tokens(100)) // Swap 100 DAPP tokens at once
      await transaction.wait() // Wait for transaction

      // Check and log investor1's balance after the large swap
      balance = await token2.balanceOf(investor1.address) // Get new USD token balance
      console.log(`Investor1 Token2 balance after swap: ${ethers.utils.formatEther(balance)} \n`) // Log new balance

      // Verify AMM's internal accounting remains accurate after large swap
      expect(await token1.balanceOf(amm.address)).to.equal(await amm.firstTokenReserve()) // Check DAPP token balance consistency
      expect(await token2.balanceOf(amm.address)).to.equal(await amm.secondTokenReserve()) // Check USD token balance consistency

      // Check and log the price after the large swap (should show dramatic price movement)
      console.log(`Price: ${await amm.secondTokenReserve() / await amm.firstTokenReserve()} \n`) // Price significantly changed due to large swap

      /////////////////////////////////////////////////////////////
      // STEP 9: INVESTOR 2 SWAPS IN OPPOSITE DIRECTION
      /////////////////////////////////////////////////////////////

      // Test swapping in the opposite direction (secondToken for firstToken)
      transaction = await token2.connect(investor2).approve(amm.address, tokens(100000)) // Investor2 approves AMM to spend USD tokens
      await transaction.wait() // Wait for approval

      // Check and log investor2's firstToken balance before swap
      balance = await token1.balanceOf(investor2.address) // Get investor2's current DAPP token balance (should be 0)
      console.log(`Investor2 Token1 balance before swap: ${ethers.utils.formatEther(balance)}`) // Log balance

      // Calculate expected output for swapping 1 USD token for DAPP tokens
      estimate = await amm.calculateSecondTokenSwap(tokens(1)) // Calculate how many DAPP tokens for 1 USD token
      console.log(`Token1 Amount investor2 will receive after swap: ${ethers.utils.formatEther(estimate)}`) // Log expected output

      // Investor2 executes the swap: 1 USD token for DAPP tokens
      transaction = await amm.connect(investor2).swapSecondToken(tokens(1)) // Call swapSecondToken function
      await transaction.wait() // Wait for transaction

      // Verify that the Swap event was emitted with correct parameters for reverse swap
      await expect(transaction).to.emit(amm, 'Swap') // Check that 'Swap' event was emitted
        .withArgs(
          investor2.address, // user who performed the swap
          await amm.secondToken(), // address of token swapped (USD token)
          tokens(1), // amount swapped (1 USD token)
          await amm.firstToken(), // address of token received (DAPP token)
          estimate, // amount received (calculated estimate)
          await amm.firstTokenReserve(), // new firstToken reserve after swap
          await amm.secondTokenReserve(), // new secondToken reserve after swap
          (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp // timestamp
        )

      // Check and log investor2's firstToken balance after swap
      balance = await token1.balanceOf(investor2.address) // Get investor2's new DAPP token balance
      console.log(`Investor2 Token1 balance after swap: ${ethers.utils.formatEther(balance)} \n`) // Log new balance
      expect(estimate).to.equal(balance) // Verify actual received amount matches estimate

      /////////////////////////////////////////////////////////////
      // STEP 10: REMOVING LIQUIDITY FROM THE POOL
      /////////////////////////////////////////////////////////////

      // Log current AMM pool balances before liquidity removal
      console.log(`AMM Token1 Balance: ${ethers.utils.formatEther(await amm.firstTokenReserve())} \n`) // Log current DAPP token reserve
      console.log(`AMM Token2 Balance: ${ethers.utils.formatEther(await amm.secondTokenReserve())} \n`) // Log current USD token reserve

      // Check and log LP's token balances before removing liquidity
      balance = await token1.balanceOf(liquidityProvider.address) // Get LP's DAPP token balance
      console.log(`Liquidity Provider Token1 balance before removing funds: ${ethers.utils.formatEther(balance)} \n`) // Log LP's DAPP balance

      balance = await token2.balanceOf(liquidityProvider.address) // Get LP's USD token balance
      console.log(`Liquidity Provider Token2 balance before removing funds: ${ethers.utils.formatEther(balance)} \n`) // Log LP's USD balance

      // LP removes all their liquidity from the AMM pool (50 shares)
      transaction = await amm.connect(liquidityProvider).removeLiquidity(shares(50)) // Remove all 50 shares that LP owns
      await transaction.wait() // Wait for removeLiquidity transaction

      // Check and log LP's token balances after removing liquidity
      balance = await token1.balanceOf(liquidityProvider.address) // Get LP's new DAPP token balance
      console.log(`Liquidity Provider Token1 balance after removing fund: ${ethers.utils.formatEther(balance)} \n`) // Log new DAPP balance

      balance = await token2.balanceOf(liquidityProvider.address) // Get LP's new USD token balance
      console.log(`Liquidity Provider Token2 balance after removing fund: ${ethers.utils.formatEther(balance)} \n`) // Log new USD balance

      // STEP 11: VERIFY LIQUIDITY REMOVAL RESULTS
      // LP should have 0 shares after removing all liquidity
      expect(await amm.userLiquidityShares(liquidityProvider.address)).to.equal(0) // LP should have no shares left

      // Deployer should still have 100 shares (unchanged)
      expect(await amm.userLiquidityShares(deployer.address)).to.equal(shares(100)) // Deployer's shares remain the same

      // AMM Pool should have 100 total shares remaining (only deployer's shares)
      expect(await amm.totalSharesCirculating()).to.equal(shares(100)) // Total shares = 150 - 50 = 100

    })

  })

})
