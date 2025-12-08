// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IFlashLoanReceiver
 * @notice Interface that flashloan borrowers must implement to receive flashloans from the AMM
 * @dev The executeOperation function will be called by the AMM during a flashloan
 */
interface IFlashLoanReceiver {
    /**
     * @notice Executes an operation after receiving the flashloaned tokens
     * @dev This function is called by the lending pool after tokens are transferred to the receiver
     * @param token The address of the token being flashloaned
     * @param amount The amount of tokens flashloaned
     * @param fee The fee that must be paid back (in addition to the principal)
     * @param initiator The address that initiated the flashloan
     * @param params Arbitrary bytes-encoded parameters passed from the initiator
     * @return bool Returns true if the operation was successful
     */
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

