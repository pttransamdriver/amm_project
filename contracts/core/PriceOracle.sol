// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniswapV3Quoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

interface ISushiSwapRouter {
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
}

contract PriceOracle {
    IUniswapV3Quoter public constant uniswapQuoter = IUniswapV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    ISushiSwapRouter public constant sushiRouter = ISushiSwapRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    
    function getUniswapPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256) {
        return uniswapQuoter.quoteExactInputSingle(
            tokenIn,
            tokenOut,
            3000, // 0.3% fee tier
            amountIn,
            0
        );
    }
    
    function getSushiPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        uint[] memory amounts = sushiRouter.getAmountsOut(amountIn, path);
        return amounts[1];
    }
    
    function findBestPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 bestPrice, bool useUniswap) {
        uint256 uniPrice = this.getUniswapPrice(tokenIn, tokenOut, amountIn);
        uint256 sushiPrice = this.getSushiPrice(tokenIn, tokenOut, amountIn);
        
        if (uniPrice > sushiPrice) {
            return (uniPrice, true);
        } else {
            return (sushiPrice, false);
        }
    }
}