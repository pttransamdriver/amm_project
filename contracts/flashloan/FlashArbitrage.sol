// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";
import "../core/AMM.sol";

interface IUniswapV3Router {
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
    
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface ISushiSwapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
}

contract FlashArbitrage {
    AutomatedMarketMaker public immutable amm;
    IUniswapV3Router public constant uniswapRouter = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ISushiSwapRouter public constant sushiRouter = ISushiSwapRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    
    uint256 private constant FLASHLOAN_FEE = 5; // 0.05%
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant SLIPPAGE_NUMERATOR = 990; // 1% max slippage
    uint256 private constant SLIPPAGE_DENOMINATOR = 1000;
    
    address public owner;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(AutomatedMarketMaker _amm) {
        amm = _amm;
        owner = msg.sender;
    }
    
    function executeArbitrage(
        address tokenA,
        address tokenB,
        uint256 amount,
        bool useUniswap
    ) external onlyOwner {
        // Get flashloan from our AMM
        uint256 fee = (amount * FLASHLOAN_FEE) / FEE_DENOMINATOR;
        
        // Execute arbitrage logic
        if (useUniswap) {
            _arbitrageUniswap(tokenA, tokenB, amount);
        } else {
            _arbitrageSushi(tokenA, tokenB, amount);
        }
        
        // Repay flashloan + fee
        require(Token(tokenA).transfer(address(amm), amount + fee), "Repayment failed");
    }
    
    function _arbitrageUniswap(address tokenA, address tokenB, uint256 amount) private {
        // Swap on Uniswap V3
        Token(tokenA).approve(address(uniswapRouter), amount);

        // Calculate minimum output with slippage tolerance
        uint256 minUniOut = (amount * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;

        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: tokenA,
            tokenOut: tokenB,
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp + 300,
            amountIn: amount,
            amountOutMinimum: minUniOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = uniswapRouter.exactInputSingle(params);

        // Swap back on our AMM with slippage protection
        Token(tokenB).approve(address(amm), amountOut);
        uint256 deadline = block.timestamp + 300;
        bool isFirstToken = (tokenA == address(amm.firstToken()));
        uint256 expectedAmmOut = isFirstToken
            ? amm.calculateSecondTokenSwap(amountOut)
            : amm.calculateFirstTokenSwap(amountOut);
        uint256 minAmmOut = (expectedAmmOut * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;

        if (isFirstToken) {
            amm.swapSecondToken(amountOut, minAmmOut, deadline);
        } else {
            amm.swapFirstToken(amountOut, minAmmOut, deadline);
        }
    }
    
    function _arbitrageSushi(address tokenA, address tokenB, uint256 amount) private {
        // Swap on SushiSwap with slippage protection
        Token(tokenA).approve(address(sushiRouter), amount);

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        // Get expected output and apply slippage tolerance
        uint[] memory expectedAmounts = sushiRouter.getAmountsOut(amount, path);
        uint256 minSushiOut = (expectedAmounts[1] * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;

        uint[] memory amounts = sushiRouter.swapExactTokensForTokens(
            amount,
            minSushiOut,
            path,
            address(this),
            block.timestamp + 300
        );

        // Swap back on our AMM with slippage protection
        Token(tokenB).approve(address(amm), amounts[1]);
        uint256 deadline2 = block.timestamp + 300;
        bool isFirstToken = (tokenA == address(amm.firstToken()));
        uint256 expectedAmmOut = isFirstToken
            ? amm.calculateSecondTokenSwap(amounts[1])
            : amm.calculateFirstTokenSwap(amounts[1]);
        uint256 minAmmOut = (expectedAmmOut * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;

        if (isFirstToken) {
            amm.swapSecondToken(amounts[1], minAmmOut, deadline2);
        } else {
            amm.swapFirstToken(amounts[1], minAmmOut, deadline2);
        }
    }
    
    function withdrawProfits(address token) external onlyOwner {
        uint256 balance = Token(token).balanceOf(address(this));
        require(Token(token).transfer(owner, balance), "Transfer failed");
    }
}