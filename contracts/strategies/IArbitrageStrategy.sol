// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IArbitrageStrategy
 * @notice Interface that all arbitrage strategies must implement
 * @dev Strategies are called by the FlashLoanHub during flashloan execution
 */
interface IArbitrageStrategy {
    /**
     * @notice Executes the arbitrage strategy
     * @param token The token that was flashloaned
     * @param amount The amount of tokens flashloaned
     * @param fee The fee that must be paid back
     * @param data Arbitrary strategy-specific data
     * @return success True if the strategy executed successfully and is profitable
     */
    function execute(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bool success);

    /**
     * @notice Estimates the profit for this strategy
     * @param token The token to use
     * @param amount The amount to flashloan
     * @param data Strategy-specific parameters
     * @return estimatedProfit The estimated profit (can be negative if unprofitable)
     */
    function estimateProfit(
        address token,
        uint256 amount,
        bytes calldata data
    ) external view returns (int256 estimatedProfit);
}

