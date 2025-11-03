// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IBalancerVault
 * @notice Interface for Balancer V2 Vault contract
 * @dev Simplified interface containing only flashloan-related functions
 */
interface IBalancerVault {
    /**
     * @notice Executes a flashloan
     * @param recipient The address which will receive the tokens and execute the callback
     * @param tokens The addresses of the tokens to flashloan
     * @param amounts The amounts of each token to flashloan
     * @param userData Arbitrary data to pass to the recipient
     */
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

/**
 * @title IBalancerFlashLoanRecipient
 * @notice Interface that must be implemented to receive Balancer flashloans
 */
interface IBalancerFlashLoanRecipient {
    /**
     * @notice Called after tokens are transferred to the recipient
     * @param tokens The addresses of the tokens that were flashloaned
     * @param amounts The amounts of each token that were flashloaned
     * @param feeAmounts The fee amounts for each token (Balancer charges 0% fee currently)
     * @param userData Arbitrary data passed from the flashLoan call
     */
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

