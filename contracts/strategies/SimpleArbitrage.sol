// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Token.sol";
import "../AMM.sol";
import "./IArbitrageStrategy.sol";

/**
 * @title SimpleArbitrage
 * @notice Executes simple 2-DEX arbitrage: Buy low on DEX A, sell high on DEX B
 * @dev This strategy borrows tokens, swaps on one DEX, then swaps back on another DEX for profit
 */
contract SimpleArbitrage is IArbitrageStrategy {
    address public immutable owner;

    struct ArbitrageParams {
        address dexA;
        address dexB;
        address tokenIn;
        address tokenOut;
        uint256 minProfit;
    }

    event ArbitrageExecuted(
        address indexed dexA,
        address indexed dexB,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function execute(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bool) {
        ArbitrageParams memory params = abi.decode(data, (ArbitrageParams));
        
        require(token == params.tokenIn, "Token mismatch");
        
        uint256 balanceBefore = Token(params.tokenIn).balanceOf(address(this));
        
        AutomatedMarketMaker dexA = AutomatedMarketMaker(params.dexA);
        AutomatedMarketMaker dexB = AutomatedMarketMaker(params.dexB);
        
        Token(params.tokenIn).approve(params.dexA, amount);
        
        uint256 amountOut;
        if (params.tokenIn == address(dexA.firstToken())) {
            amountOut = dexA.swapFirstToken(amount);
        } else {
            amountOut = dexA.swapSecondToken(amount);
        }
        
        Token(params.tokenOut).approve(params.dexB, amountOut);
        
        uint256 finalAmount;
        if (params.tokenOut == address(dexB.firstToken())) {
            finalAmount = dexB.swapFirstToken(amountOut);
        } else {
            finalAmount = dexB.swapSecondToken(amountOut);
        }
        
        uint256 balanceAfter = Token(params.tokenIn).balanceOf(address(this));
        uint256 profit = balanceAfter - balanceBefore;
        
        require(profit >= params.minProfit, "Insufficient profit");
        require(balanceAfter >= amount + fee, "Cannot repay flashloan");
        
        emit ArbitrageExecuted(params.dexA, params.dexB, amount, finalAmount, profit);
        
        return true;
    }

    function estimateProfit(
        address token,
        uint256 amount,
        bytes calldata data
    ) external view override returns (int256) {
        ArbitrageParams memory params = abi.decode(data, (ArbitrageParams));
        
        AutomatedMarketMaker dexA = AutomatedMarketMaker(params.dexA);
        AutomatedMarketMaker dexB = AutomatedMarketMaker(params.dexB);
        
        uint256 amountOut;
        if (params.tokenIn == address(dexA.firstToken())) {
            amountOut = dexA.calculateFirstTokenSwap(amount);
        } else {
            amountOut = dexA.calculateSecondTokenSwap(amount);
        }
        
        uint256 finalAmount;
        if (params.tokenOut == address(dexB.firstToken())) {
            finalAmount = dexB.calculateFirstTokenSwap(amountOut);
        } else {
            finalAmount = dexB.calculateSecondTokenSwap(amountOut);
        }
        
        int256 profit = int256(finalAmount) - int256(amount);
        
        return profit;
    }

    function withdrawProfit(address token, uint256 amount) external onlyOwner {
        Token(token).transfer(owner, amount);
    }

    receive() external payable {}
}

