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
    uint256 public totalSharesCirulating; // This variable represents the total amount of shares that are cirulating or have been issued in the L-Pool. 
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




}
