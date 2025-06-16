// Import required testing libraries and utilities
const { expect } = require('chai'); // Chai is the assertion library for testing - provides expect() function to verify test conditions
const { ethers } = require('hardhat'); // Ethers.js library for interacting with Ethereum blockchain and smart contracts

// Helper function to convert numbers to wei format (18 decimal places)
const tokens = (n) => {
  return ethers.utils.parseUnits(n.toString(), 'ether') // Converts human-readable numbers to wei. Example: tokens(100) = 100000000000000000000 wei
}

// Create an alias for the tokens function for better code readability
const ether = tokens // "ether" and "tokens" do the same thing - convert to wei format

// Main test suite for the Token contract (ERC-20 implementation)
describe('Token', () => {
  // Declare variables to hold contract instances and account addresses
  let token, // Instance of the deployed Token contract
      accounts, // Array of all available test accounts from Hardhat
      deployer, // Account that deploys the contract (accounts[0])
      receiver, // Account that receives tokens in transfer tests (accounts[1])
      exchange // Account that acts as an exchange/spender in approval tests (accounts[2])

  // beforeEach runs before every individual test case - sets up fresh contract state
  beforeEach(async () => {
    // Deploy a new Token contract for each test
    const Token = await ethers.getContractFactory('Token') // Get the Token contract factory for deployment
    token = await Token.deploy('Dapp University', 'DAPP', '1000000') // Deploy with name="Dapp University", symbol="DAPP", totalSupply=1,000,000

    // Get test accounts from Hardhat's local blockchain
    accounts = await ethers.getSigners() // Returns array of 20 test accounts with ETH balances
    deployer = accounts[0] // First account - deploys contract and receives initial token supply
    receiver = accounts[1] // Second account - used as recipient in transfer tests
    exchange = accounts[2] // Third account - used as approved spender in allowance tests
  })

  // Test suite for verifying correct contract deployment and initial state
  describe('Deployment', () => {
    // Define expected values for the deployed token contract
    const name = 'Dapp University' // Expected token name
    const symbol = 'DAPP' // Expected token symbol
    const decimals = '18' // Expected number of decimal places (standard for ERC-20)
    const totalSupply = tokens('1000000') // Expected total supply: 1,000,000 tokens in wei format

    // Test 1: Verify the token has the correct name
    it('has correct name', async () => {
      expect(await token.name()).to.equal(name) // Call name() function and verify it returns 'Dapp University'
    })

    // Test 2: Verify the token has the correct symbol
    it('has correct symbol', async () => {
      expect(await token.symbol()).to.equal(symbol) // Call symbol() function and verify it returns 'DAPP'
    })

    // Test 3: Verify the token has the correct number of decimals
    it('has correct decimals', async () => {
      expect(await token.decimals()).to.equal(decimals) // Call decimals() function and verify it returns 18
    })

    // Test 4: Verify the token has the correct total supply
    it('has correct total supply', async () => {
      expect(await token.totalSupply()).to.equal(totalSupply) // Call totalSupply() function and verify it returns 1,000,000 tokens (in wei)
    })

    // Test 5: Verify the deployer receives the entire initial token supply
    it('assigns total supply to deployer', async () => {
      expect(await token.balanceOf(deployer.address)).to.equal(totalSupply) // Check that deployer's balance equals total supply
    })

  })


  // Test suite for token transfer functionality
  describe('Sending Tokens', () => {
    let amount, transaction, result // Variables used across transfer tests

    // Test successful token transfers
    describe('Success', () => {

      // Setup for successful transfer tests - runs before each success test
      beforeEach(async () => {
        amount = tokens(100) // Set transfer amount to 100 tokens
        transaction = await token.connect(deployer).transfer(receiver.address, amount) // Execute transfer from deployer to receiver
        result = await transaction.wait() // Wait for transaction to be mined and get receipt
      })

      // Test 1: Verify that token balances are updated correctly after transfer
      it('transfers token balances', async () => {
        expect(await token.balanceOf(deployer.address)).to.equal(tokens(999900)) // Deployer should have 1,000,000 - 100 = 999,900 tokens
        expect(await token.balanceOf(receiver.address)).to.equal(amount) // Receiver should have 100 tokens
      })

      // Test 2: Verify that a Transfer event is emitted with correct parameters
      it('emits a Transfer event', async () => {
        await expect(transaction).to.emit(token, 'Transfer'). // Check that 'Transfer' event was emitted
          withArgs(deployer.address, receiver.address, amount) // Verify event parameters: from, to, amount
      })

    })

    // Test failed token transfers (edge cases and error conditions)
    describe('Failure', () => {

      // Test 3: Verify that transfers with insufficient balance are rejected
      it('rejects insufficient balances', async () => {
        const invalidAmount = tokens(100000000) // Try to transfer 100 million tokens (more than total supply)
        await expect(token.connect(deployer).transfer(receiver.address, invalidAmount)).to.be.reverted // Should revert/fail
      })

      // Test 4: Verify that transfers to invalid addresses are rejected
      it('rejects invalid recipent', async () => {
        const amount = tokens(100) // Valid transfer amount
        await expect(token.connect(deployer).transfer('0x0000000000000000000000000000000000000000', amount)).to.be.reverted // Transfer to zero address should fail
      })

    })

  })

  // Test suite for token approval functionality (ERC-20 allowance mechanism)
  describe('Approving Tokens', () => {
    let amount, transaction, result // Variables used across approval tests

    // Setup for approval tests - runs before each test in this describe block
    beforeEach(async () => {
      amount = tokens(100) // Set approval amount to 100 tokens
      transaction = await token.connect(deployer).approve(exchange.address, amount) // Deployer approves exchange to spend 100 tokens
      result = await transaction.wait() // Wait for transaction and get receipt
    })

    // Test successful token approvals
    describe('Success', () => {

      // Test 1: Verify that allowance is set correctly
      it('allocates an allowance for delegated token spending', async () => {
        expect(await token.allowance(deployer.address, exchange.address)).to.equal(amount) // Check that allowance from deployer to exchange equals 100 tokens
      })

      // Test 2: Verify that an Approval event is emitted with correct parameters
      it('emits an Approval event', async () => {
        const event = result.events[0] // Get the first event from the transaction receipt
        expect(event.event).to.equal('Approval') // Verify the event name is 'Approval'

        const args = event.args // Get the event arguments
        expect(args.owner).to.equal(deployer.address) // Verify 'owner' parameter is deployer's address
        expect(args.spender).to.equal(exchange.address) // Verify 'spender' parameter is exchange's address
        expect(args.value).to.equal(amount) // Verify 'value' parameter is the approved amount
      })

    })

    // Test failed token approvals (edge cases and error conditions)
    describe('Failure', () => {

      // Test 3: Verify that approvals to invalid addresses are rejected
      it('rejects invalid spenders', async () => {
        await expect(token.connect(deployer).approve('0x0000000000000000000000000000000000000000', amount)).to.be.reverted // Approval to zero address should fail
      })
    })

  })

  // Test suite for delegated token transfers (transferFrom functionality)
  describe('Delegated Token Transfers', () => {
    let amount, transaction, result // Variables used across delegated transfer tests

    // Setup for delegated transfer tests - approve exchange to spend tokens
    beforeEach(async () => {
      amount = tokens(100) // Set amount to 100 tokens
      transaction = await token.connect(deployer).approve(exchange.address, amount) // Deployer approves exchange to spend 100 tokens
      result = await transaction.wait() // Wait for approval transaction
    })

    // Test successful delegated transfers
    describe('Success', () => {

      // Setup for successful delegated transfer tests
      beforeEach(async () => {
        transaction = await token.connect(exchange).transferFrom(deployer.address, receiver.address, amount) // Exchange transfers tokens from deployer to receiver
        result = await transaction.wait() // Wait for transferFrom transaction
      })

      // Test 1: Verify that token balances are updated correctly after delegated transfer
      it('transfers token balances', async () => {
        expect(await token.balanceOf(deployer.address)).to.be.equal(ethers.utils.parseUnits('999900', 'ether')) // Deployer should have 999,900 tokens left
        expect(await token.balanceOf(receiver.address)).to.be.equal(amount) // Receiver should have 100 tokens
      })

      // Test 2: Verify that the allowance is reset to 0 after the transfer
      it('resets the allowance', async () => {
        expect(await token.allowance(deployer.address, exchange.address)).to.be.equal(0) // Allowance should be 0 after spending all approved tokens
      })

      // Test 3: Verify that a Transfer event is emitted with correct parameters
      it('emits a Transfer event', async () => {
        const event = result.events[0] // Get the first event from transaction receipt
        expect(event.event).to.equal('Transfer') // Verify event name is 'Transfer'

        const args = event.args // Get event arguments
        expect(args.from).to.equal(deployer.address) // Verify 'from' parameter is deployer's address
        expect(args.to).to.equal(receiver.address) // Verify 'to' parameter is receiver's address
        expect(args.value).to.equal(amount) // Verify 'value' parameter is the transferred amount
      })

    })

    // Test failed delegated transfers (edge cases and error conditions)
    describe('Failure', () => {

      // Test 4: Verify that transferFrom with insufficient allowance/balance is rejected
      it('rejects excessive transfers', async () => {
        const invalidAmount = tokens(100000000) // Try to transfer 100 million tokens (more than total supply and allowance)
        await expect(token.connect(exchange).transferFrom(deployer.address, receiver.address, invalidAmount)).to.be.reverted // Should fail
      })
    })

  })

})
