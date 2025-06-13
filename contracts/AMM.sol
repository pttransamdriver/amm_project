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
    

    // Events
    event swap(
        address indexed user,  
        address tokenSwapped,  
        uint256 amountSwapped, 
        address tokenReceived, 
        uint256 amountReceived,      
        uint256 newFirstTokenReserve, 
        uint256 newSecondTokenReserve, 
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

    function addLiquidity(uint256 _firstTokenAmount, uint256 _secondTokenAmount) external {
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

        
    }

    function calculateSecondTokenDeposit(uint256 _secondTokenAmount) public view 
    returns (uint256 requiredFirstTokenAmount)
    {
        requiredFirstTokenAmount = (firstTokenReserve * _secondTokenAmount) / secondTokenReserve; // Calculates the amount of firstToken that is required to be deposited to maintain the current pool ratio.
    }

    function calculateFirstTokenDeposit(uint256 _firstTokenAmount) public view 
    returns (uint256 requiredSecondTokenAmount)
    {
        requiredSecondTokenAmount = (secondTokenReserve * _firstTokenAmount) / firstTokenReserve; // Calculates the amount of secondToken that is required to be deposited to maintain the current pool ratio.
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
