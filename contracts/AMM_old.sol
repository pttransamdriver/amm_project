
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Token.sol";

contract AMM {
    // Token contracts for the trading pair
    Token public tokenA;
    Token public tokenB;

    // Current liquidity pool balances
    uint256 public tokenAReserve;
    uint256 public tokenBReserve;
    
    // Constant product invariant (tokenAReserve * tokenBReserve = constantProduct)
    uint256 public constantProduct;

    // Liquidity provider tracking
    uint256 public totalLiquidityShares;
    mapping(address => uint256) public liquidityProviderShares;
    uint256 constant PRECISION_FACTOR = 10**18;

    event Swap(
        address user,
        address tokenProvided,
        uint256 amountProvided,
        address tokenReceived,
        uint256 amountReceived,
        uint256 newTokenAReserve,
        uint256 newTokenBReserve,
        uint256 timestamp
    );

    constructor(Token _tokenA, Token _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(uint256 _tokenAAmount, uint256 _tokenBAmount) external {
        // Deposit Tokens
        require(
            tokenA.transferFrom(msg.sender, address(this), _tokenAAmount),
            "failed to transfer token A"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), _tokenBAmount),
            "failed to transfer token B"
        );

        // Issue Shares
        uint256 liquiditySharesIssued;

        if (totalLiquidityShares == 0) {
            liquiditySharesIssued = 100 * PRECISION_FACTOR;
        } else {
            uint256 sharesBasedOnTokenA = (totalLiquidityShares * _tokenAAmount) / tokenAReserve;
            uint256 sharesBasedOnTokenB = (totalLiquidityShares * _tokenBAmount) / tokenBReserve;
            require(
                (sharesBasedOnTokenA / 10**3) == (sharesBasedOnTokenB / 10**3),
                "must provide balanced liquidity amounts"
            );
            liquiditySharesIssued = sharesBasedOnTokenA;
        }

        // Update Pool Reserves
        tokenAReserve += _tokenAAmount;
        tokenBReserve += _tokenBAmount;
        constantProduct = tokenAReserve * tokenBReserve;

        // Updates shares
        totalLiquidityShares += liquiditySharesIssued;
        liquidityProviderShares[msg.sender] += liquiditySharesIssued;
    }

    // Calculate how many tokenB tokens must be deposited when adding liquidity with tokenA
    function calculateTokenBDeposit(uint256 _tokenAAmount)
        public
        view
        returns (uint256 requiredTokenBAmount)
    {
        requiredTokenBAmount = (tokenBReserve * _tokenAAmount) / tokenAReserve;
    }

    // Calculate how many tokenA tokens must be deposited when adding liquidity with tokenB
    function calculateTokenADeposit(uint256 _tokenBAmount)
        public
        view
        returns (uint256 requiredTokenAAmount)
    {
        requiredTokenAAmount = (tokenAReserve * _tokenBAmount) / tokenBReserve;
    }

    // Calculate amount of tokenB received when swapping tokenA
    function calculateTokenAToTokenBSwap(uint256 _tokenAAmount)
        public
        view
        returns (uint256 tokenBOutput)
    {
        uint256 tokenAReserveAfterSwap = tokenAReserve + _tokenAAmount;
        uint256 tokenBReserveAfterSwap = constantProduct / tokenAReserveAfterSwap;
        tokenBOutput = tokenBReserve - tokenBReserveAfterSwap;

        // Don't let the pool go to 0
        if (tokenBOutput == tokenBReserve) {
            tokenBOutput--;
        }

        require(tokenBOutput < tokenBReserve, "swap amount too large");
    }

    function swapTokenAForTokenB(uint256 _tokenAAmount)
        external
        returns(uint256 tokenBOutput)
    {
        // Calculate Token B Output Amount
        tokenBOutput = calculateTokenAToTokenBSwap(_tokenAAmount);

        // Execute Swap
        tokenA.transferFrom(msg.sender, address(this), _tokenAAmount);
        tokenAReserve += _tokenAAmount;
        tokenBReserve -= tokenBOutput;
        tokenB.transfer(msg.sender, tokenBOutput);

        // Emit swap event
        emit Swap(
            msg.sender,
            address(tokenA),
            _tokenAAmount,
            address(tokenB),
            tokenBOutput,
            tokenAReserve,
            tokenBReserve,
            block.timestamp
        );
    }

    // Calculate amount of tokenA received when swapping tokenB
    function calculateTokenBToTokenASwap(uint256 _tokenBAmount)
        public
        view
        returns (uint256 tokenAOutput)
    {
        uint256 tokenBReserveAfterSwap = tokenBReserve + _tokenBAmount;
        uint256 tokenAReserveAfterSwap = constantProduct / tokenBReserveAfterSwap;
        tokenAOutput = tokenAReserve - tokenAReserveAfterSwap;

        // Don't let the pool go to 0
        if (tokenAOutput == tokenAReserve) {
            tokenAOutput--;
        }

        require(tokenAOutput < tokenAReserve, "swap amount too large");
    }

    function swapTokenBForTokenA(uint256 _tokenBAmount)
        external
        returns(uint256 tokenAOutput)
    {
        // Calculate Token A Output Amount
        tokenAOutput = calculateTokenBToTokenASwap(_tokenBAmount);

        // Execute Swap
        tokenB.transferFrom(msg.sender, address(this), _tokenBAmount);
        tokenBReserve += _tokenBAmount;
        tokenAReserve -= tokenAOutput;
        tokenA.transfer(msg.sender, tokenAOutput);

        // Emit swap event
        emit Swap(
            msg.sender,
            address(tokenB),
            _tokenBAmount,
            address(tokenA),
            tokenAOutput,
            tokenAReserve,
            tokenBReserve,
            block.timestamp
        );
    }

    // Calculate withdrawal amounts based on liquidity shares
    function calculateWithdrawalAmounts(uint256 _sharesAmount)
        public
        view
        returns (uint256 tokenAAmount, uint256 tokenBAmount)
    {
        require(_sharesAmount <= totalLiquidityShares, "exceeds total available shares");
        tokenAAmount = (_sharesAmount * tokenAReserve) / totalLiquidityShares;
        tokenBAmount = (_sharesAmount * tokenBReserve) / totalLiquidityShares;
    }

    // Remove liquidity from the pool
    function removeLiquidity(uint256 _sharesAmount)
        external
        returns(uint256 tokenAAmount, uint256 tokenBAmount)
    {
        require(
            _sharesAmount <= liquidityProviderShares[msg.sender],
            "insufficient liquidity shares"
        );

        (tokenAAmount, tokenBAmount) = calculateWithdrawalAmounts(_sharesAmount);

        liquidityProviderShares[msg.sender] -= _sharesAmount;
        totalLiquidityShares -= _sharesAmount;

        tokenAReserve -= tokenAAmount;
        tokenBReserve -= tokenBAmount;
        constantProduct = tokenAReserve * tokenBReserve;

        tokenA.transfer(msg.sender, tokenAAmount);
        tokenB.transfer(msg.sender, tokenBAmount);
    }
}
