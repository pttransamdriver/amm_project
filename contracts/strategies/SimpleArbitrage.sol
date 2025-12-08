// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";
import "../core/AMM.sol";
import "./IArbitrageStrategy.sol";

/**
 * @title SimpleArbitrage
 * @notice Executes simple 2-DEX arbitrage: Buy low on DEX A, sell high on DEX B
 * @dev This strategy borrows tokens, swaps on one DEX, then swaps back on another DEX for profit
 */
// "Contract" is the default visibility for state variables and functions.
// "SampleArbitrage" is the name of the contract and "IArbitrageStrategy" is the interface it implements.
// The "IArbitrageStrategy" interface defines the functions that all arbitrage strategies must implement. This is necessary for the FlashLoanHub to interact with the strategy.
contract SimpleArbitrage is IArbitrageStrategy {
    address public immutable owner;

    // "ArbitrageParams" is a struct that holds the parameters for the arbitrage strategy.
    // Storage is byte-packed so that the last address and minProfit share a single 32-byte slot.
    struct ArbitrageParams {
        address dexA;
        address dexB;
        address tokenIn;
        address tokenOut;
        uint96 minProfit; // Fits with address tokenOut in a single storage slot (160 + 96 = 256 bits)
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

        // Anti-wash-trading: Prevent same-DEX arbitrage
        require(params.dexA != params.dexB, "DEXs must be different");
        require(params.minProfit > fee, "Min profit must exceed fee");

        uint256 balanceBefore = Token(params.tokenIn).balanceOf(address(this));

        // Execute arbitrage swaps
        uint256 finalAmount = _executeArbitrageSwaps(params, amount);

        // Check profitability
        uint256 balanceAfter = Token(params.tokenIn).balanceOf(address(this));
        uint256 profit = balanceAfter - balanceBefore;

        require(profit >= params.minProfit, "Insufficient profit");
        require(balanceAfter >= amount + fee, "Cannot repay flashloan");

        emit ArbitrageExecuted(params.dexA, params.dexB, amount, finalAmount, profit);

        return true;
    }

    function _executeArbitrageSwaps(
        ArbitrageParams memory params,
        uint256 amount
    ) private returns (uint256) {
        AutomatedMarketMaker dexA = AutomatedMarketMaker(params.dexA);
        AutomatedMarketMaker dexB = AutomatedMarketMaker(params.dexB);

        Token(params.tokenIn).approve(params.dexA, amount);
        uint256 deadline = block.timestamp + 300; // 5 minute deadline

        uint256 amountOut;
        if (params.tokenIn == address(dexA.firstToken())) {
            amountOut = dexA.swapFirstToken(amount, 0, deadline);
        } else {
            amountOut = dexA.swapSecondToken(amount, 0, deadline);
        }

        Token(params.tokenOut).approve(params.dexB, amountOut);

        uint256 finalAmount;
        if (params.tokenOut == address(dexB.firstToken())) {
            finalAmount = dexB.swapFirstToken(amountOut, 0, deadline);
        } else {
            finalAmount = dexB.swapSecondToken(amountOut, 0, deadline);
        }

        return finalAmount;
    }

    function estimateProfit(
        address,
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

