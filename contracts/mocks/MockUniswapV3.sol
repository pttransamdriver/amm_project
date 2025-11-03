// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Token.sol";

contract MockUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    
    // Mock exchange rate: 1 token = 0.95 of other token (5% worse than 1:1)
    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256 amountOut) {
        Token tokenIn = Token(params.tokenIn);
        Token tokenOut = Token(params.tokenOut);
        
        // Transfer tokens from user
        tokenIn.transferFrom(msg.sender, address(this), params.amountIn);
        
        // Calculate output with 5% worse rate + 0.3% fee
        amountOut = (params.amountIn * 95 * 997) / (100 * 1000);
        
        // Transfer output tokens to recipient
        tokenOut.transfer(params.recipient, amountOut);
    }
}

contract MockUniswapV3Quoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external pure returns (uint256 amountOut) {
        // Mock quote: 5% worse rate + 0.3% fee
        return (amountIn * 95 * 997) / (100 * 1000);
    }
}