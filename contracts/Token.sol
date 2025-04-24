// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

// Import the solidity hardhat tools
import "hardhat/console.sol";

// The "Token" Contract 
contract Token {
    // A string(or word) variable that can be seen outside the contract by using the public "visibility" flag.
    string public tokenName;
    // A string(or word) variable that can be seen outside the contract by using the public "visibility" flag.
    string public tokenSymbol; 
    // An unsigned integer variable that can be ((2^256)-1) characters long that can be seen outside the contract. This declares the decimal places of the token to have 18 decimal places making it the same as ETH. This is a common practice in the ERC20 standard
    uint256 public decimalPlaces = 18; 
    // An unsigned integer variable that can be ((2^256)-1) characters long that can be seen outside the contract. This variable is meant to keep track of the token's (the token we are making with this contract) total supply. 
    uint256 public tokenTotalSupply; 

    // Mapp
    mapping(address => uint256) public balanceOf

}