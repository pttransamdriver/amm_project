// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "hardhat/console.sol";
import "./Token.sol";


// AMM Contract declaration. Also defines tokens 1 and 2 as variables.
// Contract declares token balances and varable "k"
contract AMM {
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

    function addLiquidity(uint256 _tokenA_Amount, uint256 _tokenB_Amount) external {
        // require the deposit of tokens 
        require(
            tokenA.transferFrom(msg.sender, address(this), _tokenA_Amount), "failed to transfer token A"
        );

        require(
            tokenB.transferFrom(msg.sender, address(this), _tokenB_Amount), "failed to transfer token B"
        );

        uint256 liquditySharesIssued;
        
        // If statement declares a variable totalLiquidityShares. If it is equal to 0, then it is the first time adding liquidity.
        if (totalLiquidityShares == 0) {
            liquiditySharesIssued == 100 * PRECISION_FACTOR;
        } else {
            uint256 sharesBasedOnTokenA = (totalLiquidityShares * _tokenA_Amount) / tokenABalance;
            uint256 sharesBasedOnTokenB = (totalLiquidityShares * _tokenB_Amount) / tokenBBalance;
            require(
                (sharesBasedOnTokenA / 10**3) == (sharesBasedOnTokenB / 10**3),
                "must provide balanced liquidity amounts"
            );
            liquiditySharesIssued = sharesBasedOnTokenA;
        }

        // Update Pool Balances
        tokenABalance += _tokenA_Amount;
        tokenBBalance += _tokenB_Amount;
        constantProduct = tokenABalance * tokenBBalance;

        // Update Shares
        totalLiquidityShares += liquiditySharesIssued;
        liquidityProviderShares[msg.sender] += liquiditySharesIssued;

    }




