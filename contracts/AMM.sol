// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "hardhat/console.sol";
import "./Token.sol";


// AMM Contract declaration. Also defines tokens 1 and 2 as variables.
// Contract declares token balances and varable "k"
contract AMM {
    //Declaire Tokens:
    Token public tokenA;
    Token public tokenB;
    
    // Declare original Token Balances:
    uint256 public tokenABalance;
    uint256 public tokenBBalance;

    //Declare "Constant Product K" variable ie: (tokenAReserve * tokenBReserve = constantProduct)
    uint256 public constantProduct;

    //Liquidity Provider Tracking and precision tracking
    uint256 public totalLiquidityShares;
    uint256 constant PRECISION = 10**18;


    //Add those shares to the mapping
    mapping(address => uint256) public liquidityProviderShares;



