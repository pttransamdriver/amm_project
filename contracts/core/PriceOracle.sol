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

    // FIX Medium#6: Add access control
    address public immutable owner;

    // Simple aggregator state for lightweight TWAP-like behavior
    // WARNING: These are spot prices and can be manipulated via flash loans.
    // For production use, implement a proper TWAP or integrate Chainlink price feeds.
    uint256 public lastObservedPrice;
    uint256 public lastObservedTimestamp;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // FIX Medium#6: Internal helpers avoid external call overhead from this.fn()
    function _getUniswapPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        return uniswapQuoter.quoteExactInputSingle(
            tokenIn,
            tokenOut,
            3000, // 0.3% fee tier
            amountIn,
            0
        );
    }

    function _getSushiPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint[] memory amounts = sushiRouter.getAmountsOut(amountIn, path);
        return amounts[1];
    }

    function getUniswapPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256) {
        return _getUniswapPrice(tokenIn, tokenOut, amountIn);
    }

    function getSushiPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        return _getSushiPrice(tokenIn, tokenOut, amountIn);
    }

    // FIX Medium#6: Added onlyOwner — prevents untrusted callers from writing to state
    function findBestPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external onlyOwner returns (uint256 bestPrice, bool useUniswap) {
        uint256 uniPrice = _getUniswapPrice(tokenIn, tokenOut, amountIn);
        uint256 sushiPrice = _getSushiPrice(tokenIn, tokenOut, amountIn);
        uint256 averagePrice = (uniPrice + sushiPrice) / 2;

        lastObservedPrice = averagePrice;
        lastObservedTimestamp = block.timestamp;

        if (uniPrice > sushiPrice) {
            return (averagePrice, true);
        } else {
            return (averagePrice, false);
        }
    }

    /// @notice Very small helper that returns the last observed aggregated price and timestamp
    function getLastObserved() external view returns (uint256 price, uint256 timestamp) {
        return (lastObservedPrice, lastObservedTimestamp);
    }
}