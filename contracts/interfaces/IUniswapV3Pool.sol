// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IUniswapV3Pool
 * @notice Interface for Uniswap V3 Pool contract
 * @dev Simplified interface containing only flashloan-related functions
 */
interface IUniswapV3Pool {
    /**
     * @notice Executes a flashloan
     * @param recipient The address which will receive the token0 and token1 amounts
     * @param amount0 The amount of token0 to send
     * @param amount1 The amount of token1 to send
     * @param data Any data to be passed through to the callback
     */
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /**
     * @notice The first of the two tokens of the pool
     */
    function token0() external view returns (address);

    /**
     * @notice The second of the two tokens of the pool
     */
    function token1() external view returns (address);

    /**
     * @notice The pool's fee in hundredths of a bip (i.e., 1e-6)
     */
    function fee() external view returns (uint24);
}

/**
 * @title IUniswapV3FlashCallback
 * @notice Interface that must be implemented to receive Uniswap V3 flashloans
 */
interface IUniswapV3FlashCallback {
    /**
     * @notice Called on the callback recipient after sending tokens in a flash
     * @param fee0 The fee amount in token0 due to the pool by the end of the flash
     * @param fee1 The fee amount in token1 due to the pool by the end of the flash
     * @param data Any data passed through by the caller via the flash call
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

