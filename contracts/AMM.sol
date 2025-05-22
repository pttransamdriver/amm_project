// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "hardhat/console.sol";
import "./Token.sol";


// AMM Contract declaration. Also defines tokens 1 and 2 as variables.
// Contract declares token balances and varable "k"
contract AMM_me_edit {
    //Declaire Tokens:
    Token public tokenA;
    Token public tokenB;
    
    // Declare original Token Balances:
    uint256 public tokenABalance;
    uint256 public tokenBBalance;

    //Declare "Constant Product K" variable ie: (tokenAReserve * tokenBReserve = constantProduct)
    uint256 public constantProduct;

    //Liquidity Provider Tracking and precision tracking
    uint256 public totalLiquidityShares;
    uint256 constant PRECISION = 10**18;


    //Add those shares to the mapping
    mapping(address => uint256) public liquidityProviderShares;

    event Swap(
        address user,
        address tokenProvided,
        uint256 amountProvided,
        address tokenReceived,
        uint256 amountReceived,
        uint256 newTokenABalance,
        uint256 newTokenBBalance,
        uint256 timestamp
    );

    // Constructor function to initialize the contract with the two tokens
    constructor(Token _tokenA, Token _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        // Wait, this seems redundant to line 12 and 13 right? Well no, here is why:
        // Happy that you noticed that tokenA and tokenB are already declaired at the top as state variables. So why are we doing this again?
        // This is "initializing" the state variables with the values that have already been declared at the top of the contract. 
        // Also, this passes in parameters _tokenA and _tokenB. These will serve as the addresses for the tokens that will be used in the AMM.
        // The constructor is called when the contract is deployed, and it sets the initial values for the state variables.
    }

    // This function starts off with the 'require' statments. These require statments will require the user to deposit both TokenA and TokenB
    function addLiquidity(uint256 _tokenA_Amount, uint256 _tokenB_Amount) external {
        // 'require' the deposit of tokens via the "transferFrom" function. This also requires the approve function be called from the token contract
        require(
            tokenA.transferFrom(msg.sender, address(this), _tokenA_Amount), "failed to transfer token A"
        );
        // 'require' the deposit of tokens via the "transferFrom" function. This also requires the approve function be called from the token contract
        require(
            tokenB.transferFrom(msg.sender, address(this), _tokenB_Amount), "failed to transfer token B"
        );
        
        // Issue Shares utilizine the "ternary operator" like this: condition ? expression_if_true : expression_if_false
        uint256 liquiditySharesIssued = totalLiquidityShares == 0 
            ? 100 * PRECISION_FACTOR : (totalLiquidityShares * _tokenAAmount) / tokenAReserve;

        if (totalLiquidityShares > 0) {
            uint256 sharesBasedOnTokenB = (totalLiquidityShares * _tokenBAmount) / tokenBReserve;
            require(
                (liquiditySharesIssued / 10**3) == (sharesBasedOnTokenB / 10**3),
                "must provide balanced liquidity amounts"
            );
        }
        /* Looks like this if it was an if - else statement:
         uint256 liquiditySharesIssued;
         if (totalLiquidityShares == 0) {
           liquiditySharesIssued = 100 * PRECISION_FACTOR;
         } else {
            liquiditySharesIssued = (totalLiquidityShares * _tokenAAmount) / tokenAReserve;
         }
         */

        // Update the Liquidity Pool Balances 
        tokenABalance += _tokenA_Amount;
        tokenBBalance += _tokenB_Amount;
        constantProduct = tokenABalance * tokenBBalance;

        // Update Shares that have been haded out. Shares can build indefinatly and will be burned when shares are exchanged for tokens. 
        totalLiquidityShares += liquiditySharesIssued;
        liquidityProviderShares[msg.sender] += liquiditySharesIssued;
        
    }
    // Calculate how many tokenA tokens must be deposited when adding liquidity with tokenB
    function calculateTokenADeposit (uint256 _tokenB_Amount)
        public
        view
        returns (uint256 requiredTokenAAmount)
    {
        requiredTokenAAmount = (tokenABalance * _tokenB_Amount) / tokenBBalance;
    }

    // Calculate how many tokenB tokens must be deposited when adding liquidity with tokenA
    function calculateTokenBDeposit (uint256 _tokenA_Amount)
        public
        view
        returns (uint256 requiredTokenBAmount)
    {
        requiredTokenBAmount = (tokenBBalance * _tokenA_Amount) / tokenABalance;
    }

    // Calculate amount of tokenA received when swapping tokenB
    function calculateTokenBToTokenASwap (uint256 _tokenB_Amount)
        public
        view
        returns (uint256 tokenAOutput)
    {
        uint256 tokenBBalanceAfterSwap = tokenBBalance + _tokenB_Amount;
        uint256 tokenABalanceAfterSwap = constantProduct / tokenBBalanceAfterSwap;
        tokenAOutput = tokenABalance - tokenABalanceAfterSwap;

        // Don't let the pool go to 0
        if (tokenAOutput == tokenABalance) {
            tokenAOutput--;
        }
        // Token A Output must be less than the current balance of Token A in the pool. This requirement stops this function from being called if too many tokens are swapped.
        require(tokenAOutput < tokenABalance, "swap amount too large");
    }

    // Calculate amount of tokenB received when swapping tokenA
    function calculateTokenAToTokenBSwap (uint256 _tokenA_Amount)
        public
        view
        returns (uint256 tokenBOutput)
    {
        uint256 tokenABalanceAfterSwap = tokenABalance + _tokenA_Amount;
        uint256 tokenBBalanceAfterSwap = constantProduct / tokenABalanceAfterSwap;
        tokenBOutput = tokenBBalance - tokenBBalanceAfterSwap;

        // Don't let the pool go to 0
        if (tokenBOutput == tokenBBalance) {
            tokenBOutput--;
        }

        require(tokenBOutput < tokenBBalance, "swap amount too large");
    }





}




