// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

// Import the solidity hardhat tools
import "hardhat/console.sol";
// Import the Token contract we created
import "./Token.sol";

// The "AMM" Contract - This contract implements an Automated Market Maker (AMM) with a constant product formula (x*y=k)
// It allows users to swap between two tokens and add/remove liquidity to the pool
contract AMM {
    // Reference to the first token in the trading pair
    Token public firstToken;
    // Reference to the second token in the trading pair
    Token public secondToken;

    // The current balance of the first token in the pool
    uint256 public firstTokenBalance;
    // The current balance of the second token in the pool
    uint256 public secondTokenBalance;
    // The constant product value (K) that must be maintained after swaps (K = firstTokenBalance * secondTokenBalance)
    uint256 public constantProduct;

    // The total number of liquidity shares issued to liquidity providers
    uint256 public totalLiquidityShares;
    // Mapping that tracks how many liquidity shares each address owns
    mapping(address => uint256) public liquidityShares;
    // Constant for precision in calculations (10^18) to avoid rounding errors when dealing with small numbers
    uint256 constant PRECISION_FACTOR = 10**18;

    // Event emitted when a token swap occurs
    // Contains all relevant information about the swap for off-chain tracking and analysis
    event Swap(
        address indexed userAddress,        // The address of the user who performed the swap
        address tokenGivenAddress,          // The address of the token the user provided
        uint256 tokenGivenAmount,           // The amount of tokens the user provided
        address tokenReceivedAddress,       // The address of the token the user received
        uint256 tokenReceivedAmount,        // The amount of tokens the user received
        uint256 updatedFirstTokenBalance,   // The new balance of the first token after the swap
        uint256 updatedSecondTokenBalance,  // The new balance of the second token after the swap
        uint256 transactionTimestamp        // The timestamp when the swap occurred
    );

    // Constructor function that runs once when the contract is deployed
    // It initializes the AMM with the two tokens that will form the trading pair
    constructor(Token initialFirstToken, Token initialSecondToken) {
        // Set the first token in the trading pair
        firstToken = initialFirstToken;
        // Set the second token in the trading pair
        secondToken = initialSecondToken;
    }

    // Function that allows users to add liquidity to the pool by depositing both tokens
    // The ratio of tokens must match the current ratio in the pool (except for the first deposit)
    function addLiquidity(uint256 firstTokenAmount, uint256 secondTokenAmount) external {
        // Transfer the first token from the user to this contract
        require(
            firstToken.transferFrom(msg.sender, address(this), firstTokenAmount),
            "Failed to transfer the first token to the pool"
        );
        // Transfer the second token from the user to this contract
        require(
            secondToken.transferFrom(msg.sender, address(this), secondTokenAmount),
            "Failed to transfer the second token to the pool"
        );

        // Calculate the number of liquidity shares to issue to the user
        uint256 sharesToIssue;

        // If this is the first time adding liquidity, initialize with 100 * PRECISION_FACTOR shares
        if (totalLiquidityShares == 0) {
            // Initial liquidity provider receives 100 shares with precision factor
            sharesToIssue = 100 * PRECISION_FACTOR;
        } else {
            // Calculate shares based on the proportion of tokens being added relative to the current pool
            uint256 sharesBasedOnFirstToken = (totalLiquidityShares * firstTokenAmount) / firstTokenBalance;
            uint256 sharesBasedOnSecondToken = (totalLiquidityShares * secondTokenAmount) / secondTokenBalance;

            // Ensure the proportions are roughly equal (within 0.1% tolerance)
            require(
                (sharesBasedOnFirstToken / 10**3) == (sharesBasedOnSecondToken / 10**3),
                "Must provide tokens in the current pool ratio"
            );
            // Use the shares calculated from the first token
            sharesToIssue = sharesBasedOnFirstToken;
        }

        // Update the pool balances and constant product
        firstTokenBalance += firstTokenAmount;
        secondTokenBalance += secondTokenAmount;
        constantProduct = firstTokenBalance * secondTokenBalance;

        // Update the total shares and the user's shares
        totalLiquidityShares += sharesToIssue;
        liquidityShares[msg.sender] += sharesToIssue;
    }

    // Function to calculate how many second tokens must be deposited when adding a specific amount of first tokens
    // This helps users determine the correct ratio for adding liquidity
    function calculateSecondTokenDeposit(uint256 firstTokenAmount)
        public
        view
        returns (uint256 secondTokenAmount)
    {
        // Calculate the required amount of second token based on the current ratio in the pool
        secondTokenAmount = (secondTokenBalance * firstTokenAmount) / firstTokenBalance;
    }

    // Function to calculate how many first tokens must be deposited when adding a specific amount of second tokens
    // This helps users determine the correct ratio for adding liquidity
    function calculateFirstTokenDeposit(uint256 secondTokenAmount)
        public
        view
        returns (uint256 firstTokenAmount)
    {
        // Calculate the required amount of first token based on the current ratio in the pool
        firstTokenAmount = (firstTokenBalance * secondTokenAmount) / secondTokenBalance;
    }

    // Function to calculate how many second tokens a user will receive when swapping first tokens
    // Uses the constant product formula (x*y=k) to determine the output amount
    function calculateFirstTokenSwap(uint256 firstTokenAmount)
        public
        view
        returns (uint256 secondTokenAmount)
    {
        // Calculate the new balance of the first token after the swap
        uint256 firstTokenAfterSwap = firstTokenBalance + firstTokenAmount;
        // Calculate the new balance of the second token using the constant product formula
        uint256 secondTokenAfterSwap = constantProduct / firstTokenAfterSwap;
        // Calculate how many second tokens will be removed from the pool
        secondTokenAmount = secondTokenBalance - secondTokenAfterSwap;

        // Safety check to prevent the pool from being completely drained
        if (secondTokenAmount == secondTokenBalance) {
            // Reduce by 1 to ensure some liquidity remains
            secondTokenAmount--;
        }

        // Ensure the swap amount is not too large for the pool
        require(secondTokenAmount < secondTokenBalance, "Swap amount too large for the pool");
    }

    // Function that allows users to swap first tokens for second tokens
    // Returns the amount of second tokens received
    function swapFirstToken(uint256 firstTokenAmount)
        external
        returns(uint256 secondTokenAmount)
    {
        // Calculate how many second tokens the user will receive
        secondTokenAmount = calculateFirstTokenSwap(firstTokenAmount);

        // Execute the swap
        // Transfer first tokens from the user to this contract
        firstToken.transferFrom(msg.sender, address(this), firstTokenAmount);
        // Update the first token balance
        firstTokenBalance += firstTokenAmount;
        // Update the second token balance
        secondTokenBalance -= secondTokenAmount;
        // Transfer second tokens from this contract to the user
        secondToken.transfer(msg.sender, secondTokenAmount);

        // Emit a Swap event to log this transaction on the blockchain
        emit Swap(
            msg.sender,                // User who performed the swap
            address(firstToken),       // Token given by the user
            firstTokenAmount,          // Amount of tokens given
            address(secondToken),      // Token received by the user
            secondTokenAmount,         // Amount of tokens received
            firstTokenBalance,         // Updated first token balance
            secondTokenBalance,        // Updated second token balance
            block.timestamp            // Current block timestamp
        );
    }

    // Function to calculate how many first tokens a user will receive when swapping second tokens
    // Uses the constant product formula (x*y=k) to determine the output amount
    function calculateSecondTokenSwap(uint256 secondTokenAmount)
        public
        view
        returns (uint256 firstTokenAmount)
    {
        // Calculate the new balance of the second token after the swap
        uint256 secondTokenAfterSwap = secondTokenBalance + secondTokenAmount;
        // Calculate the new balance of the first token using the constant product formula
        uint256 firstTokenAfterSwap = constantProduct / secondTokenAfterSwap;
        // Calculate how many first tokens will be removed from the pool
        firstTokenAmount = firstTokenBalance - firstTokenAfterSwap;

        // Safety check to prevent the pool from being completely drained
        if (firstTokenAmount == firstTokenBalance) {
            // Reduce by 1 to ensure some liquidity remains
            firstTokenAmount--;
        }

        // Ensure the swap amount is not too large for the pool
        require(firstTokenAmount < firstTokenBalance, "Swap amount too large for the pool");
    }

    // Function that allows users to swap second tokens for first tokens
    // Returns the amount of first tokens received
    function swapSecondToken(uint256 secondTokenAmount)
        external
        returns(uint256 firstTokenAmount)
    {
        // Calculate how many first tokens the user will receive
        firstTokenAmount = calculateSecondTokenSwap(secondTokenAmount);

        // Execute the swap
        // Transfer second tokens from the user to this contract
        secondToken.transferFrom(msg.sender, address(this), secondTokenAmount);
        // Update the second token balance
        secondTokenBalance += secondTokenAmount;
        // Update the first token balance
        firstTokenBalance -= firstTokenAmount;
        // Transfer first tokens from this contract to the user
        firstToken.transfer(msg.sender, firstTokenAmount);

        // Emit a Swap event to log this transaction on the blockchain
        emit Swap(
            msg.sender,                // User who performed the swap
            address(secondToken),      // Token given by the user
            secondTokenAmount,         // Amount of tokens given
            address(firstToken),       // Token received by the user
            firstTokenAmount,          // Amount of tokens received
            firstTokenBalance,         // Updated first token balance
            secondTokenBalance,        // Updated second token balance
            block.timestamp            // Current block timestamp
        );
    }

    // Function to calculate how many tokens a user will receive when withdrawing a specific number of shares
    // Returns the amounts of both tokens that will be withdrawn
    function calculateWithdrawAmount(uint256 sharesToWithdraw)
        public
        view
        returns (uint256 firstTokenAmount, uint256 secondTokenAmount)
    {
        // Ensure the user is not trying to withdraw more shares than exist
        require(sharesToWithdraw <= totalLiquidityShares, "Cannot withdraw more shares than exist in the pool");

        // Calculate the proportion of the pool that the shares represent
        // Then multiply by the current token balances to get the withdrawal amounts
        firstTokenAmount = (sharesToWithdraw * firstTokenBalance) / totalLiquidityShares;
        secondTokenAmount = (sharesToWithdraw * secondTokenBalance) / totalLiquidityShares;
    }

    // Function that allows users to remove liquidity from the pool
    // Returns the amounts of both tokens that were withdrawn
    function removeLiquidity(uint256 sharesToWithdraw)
        external
        returns(uint256 firstTokenAmount, uint256 secondTokenAmount)
    {
        // Ensure the user is not trying to withdraw more shares than they own
        require(
            sharesToWithdraw <= liquidityShares[msg.sender],
            "Cannot withdraw more shares than you own"
        );

        // Calculate the amounts of tokens to withdraw based on the shares
        (firstTokenAmount, secondTokenAmount) = calculateWithdrawAmount(sharesToWithdraw);

        // Update the user's shares and the total shares
        liquidityShares[msg.sender] -= sharesToWithdraw;
        totalLiquidityShares -= sharesToWithdraw;

        // Update the pool balances and constant product
        firstTokenBalance -= firstTokenAmount;
        secondTokenBalance -= secondTokenAmount;
        constantProduct = firstTokenBalance * secondTokenBalance;

        // Transfer the tokens from this contract to the user
        firstToken.transfer(msg.sender, firstTokenAmount);
        secondToken.transfer(msg.sender, secondTokenAmount);
    }
}