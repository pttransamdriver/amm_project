// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";

contract MockSushiSwapRouter {
    // Mock exchange rate: 1 token = 1.05 of other token (5% better than 1:1)
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        Token tokenIn = Token(path[0]);
        Token tokenOut = Token(path[1]);
        
        // Transfer tokens from user
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        
        // Calculate output with 5% better rate - 0.3% fee
        uint amountOut = (amountIn * 105 * 997) / (100 * 1000);
        
        // Transfer output tokens to recipient
        tokenOut.transfer(to, amountOut);
        
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external pure returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = amountIn;
        // Mock quote: 5% better rate - 0.3% fee
        amounts[1] = (amountIn * 105 * 997) / (100 * 1000);
    }
}