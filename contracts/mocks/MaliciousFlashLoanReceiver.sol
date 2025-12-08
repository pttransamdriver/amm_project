// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";
import "../core/AMM.sol";
import "../flashloan/IFlashLoanReceiver.sol";

/**
 * @title MaliciousFlashLoanReceiver
 * @notice Demonstrates wash trading vulnerability using flashloans
 * @dev FOR TESTING PURPOSES ONLY - Shows how attacker can trade on same AMM during flashloan
 */
contract MaliciousFlashLoanReceiver is IFlashLoanReceiver {
    AutomatedMarketMaker public immutable amm;
    Token public immutable token1;
    Token public immutable token2;
    
    constructor(address _amm, address _token1, address _token2) {
        amm = AutomatedMarketMaker(_amm);
        token1 = Token(_token1);
        token2 = Token(_token2);
    }
    
    /**
     * @notice Executes wash trade during flashloan
     * @dev This demonstrates the vulnerability - should be prevented by AMM
     */
    function executeWashTrade(uint256 amount) external {
        // Request flashloan from AMM
        bytes memory params = abi.encode(amount);
        amm.flashLoanFirstToken(amount, params);
    }
    
    /**
     * @notice Callback from AMM flashloan
     * @dev Attempts to trade on same AMM - THIS SHOULD FAIL
     */
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(amm), "Invalid caller");
        
        // VULNERABILITY: Trading on same AMM during flashloan
        // This manipulates price with zero capital
        
        // Approve AMM to spend flashloaned tokens
        token1.approve(address(amm), amount);

        uint256 deadline = block.timestamp + 300; // 5 minute deadline

        // Execute wash trade - swap flashloaned tokens
        // This should be prevented but might not be
        uint256 token2Received = amm.swapFirstToken(amount / 2, 0, deadline);

        // Swap back
        token2.approve(address(amm), token2Received);
        amm.swapSecondToken(token2Received, 0, deadline);
        
        // Approve repayment
        token1.approve(address(amm), amount + fee);
        
        return true;
    }
}

