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
    ) external {
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
        
        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: tokenA,
            tokenOut: tokenB,
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp + 300,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut = uniswapRouter.exactInputSingle(params);
        
        // Swap back on our AMM
        Token(tokenB).approve(address(amm), amountOut);
        uint256 deadline = block.timestamp + 300;
        if (tokenA == address(amm.firstToken())) {
            amm.swapSecondToken(amountOut, 0, deadline);
        } else {
            amm.swapFirstToken(amountOut, 0, deadline);
        }
    }
    
    function _arbitrageSushi(address tokenA, address tokenB, uint256 amount) private {
        // Swap on SushiSwap
        Token(tokenA).approve(address(sushiRouter), amount);
        
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        
        uint[] memory amounts = sushiRouter.swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Swap back on our AMM
        Token(tokenB).approve(address(amm), amounts[1]);
        uint256 deadline2 = block.timestamp + 300;
        if (tokenA == address(amm.firstToken())) {
            amm.swapSecondToken(amounts[1], 0, deadline2);
        } else {
            amm.swapFirstToken(amounts[1], 0, deadline2);
        }
    }
    
    function withdrawProfits(address token) external onlyOwner {
        uint256 balance = Token(token).balanceOf(address(this));
        Token(token).transfer(owner, balance);
    }
}