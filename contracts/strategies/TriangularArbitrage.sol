// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";
import "../core/AMM.sol";
import "./IArbitrageStrategy.sol";

/**
 * @title TriangularArbitrage
 * @notice Executes triangular arbitrage across 3 tokens: A -> B -> C -> A
 * @dev Exploits price discrepancies in a cycle of three token pairs
 */
contract TriangularArbitrage is IArbitrageStrategy {
    address public immutable owner;
    address public authorizedCaller;

    uint256 private constant SLIPPAGE_NUMERATOR = 995; // 0.5% max slippage
    uint256 private constant SLIPPAGE_DENOMINATOR = 1000;

    // Storage is byte-packed so that tokenC and minProfit share a single 32-byte slot.
    struct TriangularParams {
        address dex1;
        address dex2;
        address dex3;
        address tokenA;
        address tokenB;
        address tokenC;
        uint96 minProfit; // Fits with address tokenC (160 + 96 = 256 bits)
    }

    event TriangularArbitrageExecuted(
        address indexed tokenA,
        address indexed tokenB,
        address indexed tokenC,
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

    function setAuthorizedCaller(address _caller) external onlyOwner {
        authorizedCaller = _caller;
    }

    function execute(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bool) {
        require(msg.sender == authorizedCaller || msg.sender == owner, "Unauthorized caller");
        TriangularParams memory params = abi.decode(data, (TriangularParams));

        require(token == params.tokenA, "Token mismatch");

        // Anti-wash-trading: Ensure all DEXs are different
        require(params.dex1 != params.dex2, "DEX1 and DEX2 must be different");
        require(params.dex2 != params.dex3, "DEX2 and DEX3 must be different");
        require(params.dex1 != params.dex3, "DEX1 and DEX3 must be different");
        require(params.minProfit > fee, "Min profit must exceed fee");

        uint256 balanceBefore = Token(params.tokenA).balanceOf(address(this));

        Token(params.tokenA).approve(params.dex1, amount);
        uint256 amountB = _swap(AutomatedMarketMaker(params.dex1), params.tokenA, amount);

        Token(params.tokenB).approve(params.dex2, amountB);
        uint256 amountC = _swap(AutomatedMarketMaker(params.dex2), params.tokenB, amountB);

        Token(params.tokenC).approve(params.dex3, amountC);
        uint256 finalAmountA = _swap(AutomatedMarketMaker(params.dex3), params.tokenC, amountC);

        uint256 balanceAfter = Token(params.tokenA).balanceOf(address(this));

        require(balanceAfter > balanceBefore, "No profit");

        unchecked {
            uint256 profit = balanceAfter - balanceBefore;
            require(profit >= params.minProfit, "Insufficient profit");
        }

        require(balanceAfter >= amount + fee, "Cannot repay flashloan");

        emit TriangularArbitrageExecuted(
            params.tokenA,
            params.tokenB,
            params.tokenC,
            amount,
            finalAmountA,
            balanceAfter - balanceBefore
        );

        return true;
    }

    function _swap(
        AutomatedMarketMaker dex,
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256) {
        uint256 deadline = block.timestamp + 300; // 5 minute deadline
        bool isFirstToken = (tokenIn == address(dex.firstToken()));
        uint256 expectedOut = isFirstToken
            ? dex.calculateFirstTokenSwap(amountIn)
            : dex.calculateSecondTokenSwap(amountIn);
        uint256 minAmountOut = (expectedOut * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;

        if (isFirstToken) {
            return dex.swapFirstToken(amountIn, minAmountOut, deadline);
        } else {
            return dex.swapSecondToken(amountIn, minAmountOut, deadline);
        }
    }

    function estimateProfit(
        address,
        uint256 amount,
        bytes calldata data
    ) external view override returns (int256) {
        TriangularParams memory params = abi.decode(data, (TriangularParams));
        
        AutomatedMarketMaker dex1 = AutomatedMarketMaker(params.dex1);
        AutomatedMarketMaker dex2 = AutomatedMarketMaker(params.dex2);
        AutomatedMarketMaker dex3 = AutomatedMarketMaker(params.dex3);
        
        uint256 amountB = _estimateSwap(dex1, params.tokenA, amount);
        uint256 amountC = _estimateSwap(dex2, params.tokenB, amountB);
        uint256 finalAmountA = _estimateSwap(dex3, params.tokenC, amountC);
        
        int256 profit = int256(finalAmountA) - int256(amount);
        
        return profit;
    }

    function _estimateSwap(
        AutomatedMarketMaker dex,
        address tokenIn,
        uint256 amountIn
    ) internal view returns (uint256) {
        if (tokenIn == address(dex.firstToken())) {
            return dex.calculateFirstTokenSwap(amountIn);
        } else {
            return dex.calculateSecondTokenSwap(amountIn);
        }
    }

    function withdrawProfit(address token, uint256 amount) external onlyOwner {
        Token(token).transfer(owner, amount);
    }

    receive() external payable {}
}

