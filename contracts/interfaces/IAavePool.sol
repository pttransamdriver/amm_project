// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAavePool
 * @notice Interface for Aave V3 Pool contract
 * @dev Simplified interface containing only flashloan-related functions
 */
interface IAavePool {
    /**
     * @notice Executes a flashloan
     * @param receiverAddress The address of the contract receiving the funds
     * @param assets The addresses of the assets being flashloaned
     * @param amounts The amounts of the assets being flashloaned
     * @param interestRateModes Types of debt to open if the flashloan is not returned (0 = no debt)
     * @param onBehalfOf The address that will receive the debt (if applicable)
     * @param params Arbitrary bytes-encoded params to pass to the receiver
     * @param referralCode Referral code for integrators (use 0)
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Returns the fee for flashloans (in basis points)
     * @return The flashloan premium (e.g., 9 = 0.09%)
     */
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}

/**
 * @title IFlashLoanSimpleReceiver
 * @notice Interface that must be implemented to receive Aave flashloans
 */
interface IFlashLoanSimpleReceiver {
    /**
     * @notice Executes an operation after receiving the flashloaned assets
     * @param asset The address of the flashloaned asset
     * @param amount The amount of the flashloaned asset
     * @param premium The fee of the flashloan
     * @param initiator The address of the flashloan initiator
     * @param params Arbitrary bytes-encoded params passed when initiating the flashloan
     * @return bool Returns true if the execution was successful
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

