// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "hardhat/console.sol";
import "./Token.sol";

contract AutomatedMarketMaker {
    // Tokens that are interacted with external to the contract (What the user sees/gets)
    Token public firstToken;
    Token public secondToken;

    // State Variables for the Liquididty Pool.
    uint256 public firstTokenReserve; // This variable represents the amount of "firstToken" in the L-Pool.
    uint256 public secondTokenReserve; // This variable represents the amount of "secondToken" in the L-Pool.
    uint256 public constantProductK; // This variable represents the constant product (k) in the formula x * y = k. It needs to be declared here to be used in multiple functions later. 

    // Accounting state variables. 
    uint256 public totalSharesCirculating; // This variable represents the total amount of shares that are cirulating or have been issued in the L-Pool. 
    mapping(address => uint256) public userLiquidityShares; // This mapping represents the amount of shares that each user has in the L-Pool.    
    uint256 constant PRECISION = 10**18; // "PRECISION" is a constant variable and is therefor in all caps in keeping with the solidity style guide. The value is 10 to the 18 power (10**18, different from 10^18 which means something else in solidity).
    bool locked;
    modifier nonReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;        
    }
    

    // Events
    event Swap(
        address indexed user,
        address tokenSwapped,
        uint256 amountSwapped,
        address tokenReceived,
        uint256 amountReceived,
        uint256 newFirstTokenReserve,
        uint256 newSecondTokenReserve,
        uint256 timestamp
    );

    event AddLiquidity(
        address indexed provider,
        uint256 firstTokenAmount,
        uint256 secondTokenAmount,
        uint256 liquiditySharestoMint,
        uint256 timestamp
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 sharesRedeemed,
        uint256 firstTokenAmount,
        uint256 secondTokenAmount,
        uint256 timestamp
    );

    /*
    event swap( // Just an explanation of the swap events
        address indexed user,  // This means that the user address will be indexed and can be used to filter events.
        address tokenSwapped,  // "tokenSwapped" is the address of the token that was provided to the L-Pool. You can import as many token contract addresses into the AMM as you like. 
        uint256 amountSwapped, // "amountSwapped" is the amount of tokens that were provided to the L-Pool.
        address tokenReceived, // "tokenReceived" is the address of the token that was taken out of the L-Pool and given to the user.
        uint256 amountReceived,      // "amountReceived" is the amount of tokens that were taken out of the L-Pool and given to the user.
        uint256 newFirstTokenReserve, // "newFirstTokenReserve" is the new amount of "firstToken" in the L-Pool after the swap.
        uint256 newSecondTokenReserve, // "newSecondTokenReserve" is the new amount of "secondToken" in the L-Pool after the swap.
        uint256 timestamp // "timestamp" is the time at which the swap occurred.
        */

    constructor(Token _firstToken, Token _secondToken) { // Consructor expecting Token.sol contract to be deployed twice, once for firstToken and 2nd for secondToken.
        firstToken = _firstToken; // "firstToken" is the state variable and "_firstToken" is the parameter used for the internal contract use. 
        secondToken = _secondToken; // "secondToken" is the state variable and "_secondToken" is the parameter used for the internal contract use.
    }

    function addLiquidity(uint256 _firstTokenAmount, uint256 _secondTokenAmount) external
        nonReentrant()
    {
        // Externally called by the users or other contracts like metamask to add liquidity to the L-Pool. It interacts with the Token.sol contracts to transfer the tokens from the user to the L-Pool.
        require(
            firstToken.transferFrom(msg.sender, address(this), _firstTokenAmount), // Calls the builtin "transferFrom" function in the Token.sol contract and requires tokens to transfer from the user "msg.sender" to the L-Pool "address(this)" for the amount of "_firstTokenAmount".
            "Failed to transfer firstToken to the pool" // Error message if the require statment fails.        
        );
        require(
            secondToken.transferFrom(msg.sender, address(this), _secondTokenAmount), // Calls the builtin "transferFrom" function in the Token.sol contract and requires tokens to transfer from the user "msg.sender" to the L-Pool "address(this)" for the amount of "_secondTokenAmount".
            "Failed to transfer secondToken to the pool" // Error message if the require statment fails.        
        );

        uint256 liquiditySharestoMint; // This variable represents the amount of shares that will be minted for the user.

        // Initial liquidity provision
        if (totalSharesCirculating == 0) { // This if statement asks if the totalLiquidityShares is equal to 0. If it is, then the "liquiditySharestoMint" is set to 100 * PRECISION. 
            liquiditySharestoMint = 100 * PRECISION; // The first person to add liquidity to the pool gets 100 shares. Think of the shares like ETH. Total ETH is measured in WEI and 1 ETH is 1*10^18 Wei. So 100 (whole) shares is 100*10^18 (100 * PRECISION).            
        } else {
            // Now we need to calculate the amount of share to give out to 2nd, 3rd, 4th etc liquidity providers. 
            uint256 proportionalSharesFromFirstToken = (totalSharesCirculating * _firstTokenAmount) / firstTokenReserve; // Calculate the shares the subsequent liquidity providers should get based on the amount of firstToken they provided. 
            uint256 proportionalSharesFromSecondToken = (totalSharesCirculating * _secondTokenAmount) / secondTokenReserve; // Calculate the shares the subsequent liquidity providers should get based on the amount of secondToken they provided. 
            
            // Verify deposit ratio matches current pool ratio (allowing 0.1% deviation)
            require(
                (proportionalSharesFromFirstToken / 10**3) == (proportionalSharesFromSecondToken / 10**3),
                "Must provide tokens in the current pool ratio"
            );
            liquiditySharestoMint = proportionalSharesFromFirstToken;
        }

        // Update state variables
        firstTokenReserve += _firstTokenAmount;
        secondTokenReserve += _secondTokenAmount;
        constantProductK = firstTokenReserve * secondTokenReserve;

        // Update liquidity accounting
        totalSharesCirculating += liquiditySharestoMint; // The total amount of shares that are cirulating plus the amount of shares that will be minted for the users deposit. Updating the State Variable.
        userLiquidityShares[msg.sender] += liquiditySharestoMint; // The total amount of shares that the user has in the L-Pool plus the amount of shares that will be minted for the users deposit. Updating the user's share balance.

        // Emit AddLiquidity event
        emit AddLiquidity(
            msg.sender,
            _firstTokenAmount,
            _secondTokenAmount,
            liquiditySharestoMint,
            block.timestamp
        );
        
    }

    function calculateSecondTokenDeposit(uint256 _secondTokenAmount) public view
        returns (uint256 requiredFirstTokenAmount)
    {
        require(_secondTokenAmount > 0, "Second token amount must be greater than 0");
        require(secondTokenReserve > 0, "Pool not initialized");
        requiredFirstTokenAmount = (firstTokenReserve * _secondTokenAmount) / secondTokenReserve; // Calculates the amount of firstToken that is required to be deposited to maintain the current pool ratio.
    }

    function calculateFirstTokenDeposit(uint256 _firstTokenAmount) public view
        returns (uint256 requiredSecondTokenAmount)
    {
        require(_firstTokenAmount > 0, "First token amount must be greater than 0");
        require(firstTokenReserve > 0, "Pool not initialized");
        requiredSecondTokenAmount = (secondTokenReserve * _firstTokenAmount) / firstTokenReserve; // Calculates the amount of secondToken that is required to be deposited to maintain the current pool ratio.
    }

    function calculateFirstTokenSwap(uint256 _firstTokenAmount) public view // View Function to see how many tokens you would receive if you swapped a certain amount of firstToken.
        returns (uint256 secondTokenOut)
    {
        require(_firstTokenAmount > 0, "Swap amount must be greater than 0"); // Requires that the amount of firstToken that is being swapped is greater than 0.
        require(firstTokenReserve > 0 && secondTokenReserve > 0, "Invalid pool reserves"); // Requires that the amount of firstToken and secondToken in the pool is greater than 0.
        require(constantProductK > 0, "Pool not properly initialized");
        uint256 amountInWithFee = (_firstTokenAmount * 997) / 1000; // 0.3% fee
        uint256 firstTokenAfterSwap = firstTokenReserve + amountInWithFee; // Calculates the amount of firstToken in the pool after the swap.

        require(firstTokenAfterSwap > 0, "Invalid swap amount: zero reserves after swap");
        uint256 secondTokenAfterSwap = constantProductK / firstTokenAfterSwap; // Calculates the amount of secondToken in the pool after the swap.
        secondTokenOut = secondTokenReserve - secondTokenAfterSwap; // Calculates the amount of secondToken that will be given to the user after the swap.

        // Safety check: Don't drain the entire pool
        if (secondTokenOut == secondTokenReserve) {
            secondTokenOut--; // Subtracts an extra one token if the tokenB is equal to the amount of tokenB in the pool
        }

        require(secondTokenOut < secondTokenReserve, "Swap amount too large for pool reserves"); // Requires that the amount of secondToken that will be given to the user is less than the amount of secondToken in the pool.
        return(secondTokenOut);

    }

    function swapFirstToken(uint256 _firstTokenAmount) external
        nonReentrant()
        returns (uint256 secondTokenOutput)
    
    {
        secondTokenOutput = calculateFirstTokenSwap(_firstTokenAmount); // Calculates the amount of secondToken that will be given to the user after the swap.

        // Transfer tokens from user to pool
        require(firstToken.transferFrom(msg.sender, address(this), _firstTokenAmount),"Failed to transfer firstToken to the pool"
        );

        // Update pool reserves
        firstTokenReserve += _firstTokenAmount;   // Add the amount of firstToken that was swapped to the pool reserve.
        secondTokenReserve -= secondTokenOutput;  // Subtract the amount of secondToken that was given to the user from the pool reserve.
        secondToken.transfer(msg.sender, secondTokenOutput); // Transfer the amount of secondToken that was given to the user from the pool to the user.

        // Emit the swap event to log the swap
        emit Swap(
            msg.sender,
            address(firstToken),
            _firstTokenAmount,
            address(secondToken),
            secondTokenOutput,
            firstTokenReserve,
            secondTokenReserve,
            block.timestamp
        );
    }


    function calculateSecondTokenSwap(uint256 _secondTokenAmount) public view
        returns (uint256 firstTokenOut)
    {
        require(_secondTokenAmount > 0, "Swap amount must be greater than 0"); // Requires that the amount of secondToken that is being swapped is greater than 0.
        require(firstTokenReserve > 0 && secondTokenReserve > 0, "Invalid pool reserves"); // Requires that the amount of firstToken and secondToken in the pool is greater than 0.
        require(constantProductK > 0, "Pool not properly initialized");
        uint256 amountInWithFee = (_secondTokenAmount * 997) / 1000; // 0.3% fee
        uint256 secondTokenAfterSwap = secondTokenReserve + amountInWithFee; // Calculates the amount of secondToken in the pool after the swap.
        
        require(secondTokenAfterSwap > 0, "Invalid swap amount: zero reserves after swap");
        uint256 firstTokenAfterSwap = constantProductK / secondTokenAfterSwap; // Calculates the amount of firstToken in the pool after the swap.
        firstTokenOut = firstTokenReserve - firstTokenAfterSwap; // Calculates the amount of firstToken that will be given to the user after the swap.

        // Safety check: Don't drain the entire pool
        if (firstTokenOut == firstTokenReserve) {
            firstTokenOut--;
        }

        require(firstTokenOut < firstTokenReserve, "Swap amount too large for pool reserves"); // Requires that the amount of firstToken that will be given to the user is less than the amount of firstToken in the pool.
        return(firstTokenOut);
    }

    function swapSecondToken(uint256 _secondTokenAmount) external
        nonReentrant()
        returns (uint256 firstTokenOutput)
    {
        firstTokenOutput = calculateSecondTokenSwap(_secondTokenAmount); // Calculates the amount of firstToken that will be given to the user after the swap.

        // Transfer tokens from user to pool
        require(secondToken.transferFrom(msg.sender, address(this), _secondTokenAmount),"Failed to transfer secondToken to the pool"
        );

        // Update pool reserves
        secondTokenReserve += _secondTokenAmount;   // Add the amount of secondToken that was swapped to the pool reserve.
        firstTokenReserve -= firstTokenOutput;  // Subtract the amount of firstToken that was given to the user from the pool reserve.
        firstToken.transfer(msg.sender, firstTokenOutput); // Transfer the amount of firstToken that was given to the user from the pool to the user.

        // Emit the swap event to log the swap
        emit Swap(
            msg.sender,
            address(secondToken),
            _secondTokenAmount,
            address(firstToken),
            firstTokenOutput,
            firstTokenReserve,
            secondTokenReserve,
            block.timestamp
        );
    }

    function removeLiquidity(uint256 _sharesToWithdraw) external
        nonReentrant()
        returns(uint256 firstTokenAmount, uint256 secondTokenAmount)
    {
        require(_sharesToWithdraw > 0, "Shares to withdraw must be greater than 0");
        require(_sharesToWithdraw <= userLiquidityShares[msg.sender], "Cannot withdraw more shares than you own");
        require(totalSharesCirculating > 0, "No liquidity in pool");

        // Calculate the tokens the user is entitled to withdraw
        firstTokenAmount = (_sharesToWithdraw * firstTokenReserve) / totalSharesCirculating;
        secondTokenAmount = (_sharesToWithdraw * secondTokenReserve) / totalSharesCirculating;

        // Update state variables
        totalSharesCirculating -= _sharesToWithdraw;
        userLiquidityShares[msg.sender] -= _sharesToWithdraw;

        // Update reserves
        firstTokenReserve -= firstTokenAmount;
        secondTokenReserve -= secondTokenAmount;

        // Update constant product K
        constantProductK = firstTokenReserve * secondTokenReserve;

        // Transfer tokens to user
        require(firstToken.transfer(msg.sender, firstTokenAmount), "Failed to transfer firstToken");
        require(secondToken.transfer(msg.sender, secondTokenAmount), "Failed to transfer secondToken");

        // Emit RemoveLiquidity event
        emit RemoveLiquidity(
            msg.sender,
            _sharesToWithdraw,
            firstTokenAmount,
            secondTokenAmount,
            block.timestamp
        );

        return (firstTokenAmount, secondTokenAmount);
    }
}




/*
Math Explaination for Lines 66-78 (The "if" statement):
How does it work?
totalLiquidityShares is the total number of shares currently issued.
tokenAReserve and tokenBReserve are the current amounts of each token in the pool.
_tokenAAmount and _tokenBAmount are the amounts the user wants to deposit.
For tokenA:
(totalLiquidityShares * _tokenAAmount) / tokenAReserve
This means:
“If I’m depositing X% of the current tokenA reserve, I should get X% of the current total shares.”
For tokenB:
(totalLiquidityShares * _tokenBAmount) / tokenBReserve
Same logic, but for tokenB.
Why calculate both?
The pool requires that the user deposit tokens in the same ratio as the pool currently holds.
The code checks that the calculated shares from both tokens are (almost) equal (within 0.1%).
This prevents users from unbalancing the pool by depositing more of one token than the other.
Example:
Suppose:

Pool has 1000 tokenA and 2000 tokenB
There are 100 * 10¹⁸ total shares
User wants to deposit 100 tokenA and 200 tokenB
Then:

proportionalSharesFromA = (100 * 10¹⁸ * 100) / 1000 = 10 * 10¹⁸
proportionalSharesFromB = (100 * 10¹⁸ * 200) / 2000 = 10 * 10¹⁸
So the user would receive 10 * 10¹⁸ new shares.
*/
