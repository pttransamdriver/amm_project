// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Token.sol";
import "./IFlashLoanReceiver.sol";

contract AutomatedMarketMaker {
    Token public immutable firstToken;
    Token public immutable secondToken;

    uint256 public firstTokenReserve;
    uint256 public secondTokenReserve;
    uint256 public constantProductK;

    uint256 public totalSharesCirculating;
    mapping(address => uint256) public userLiquidityShares;

    uint256 private constant PRECISION = 10**18;
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    uint256 private constant FLASHLOAN_FEE_NUMERATOR = 9;
    uint256 private constant FLASHLOAN_FEE_DENOMINATOR = 10000;

    uint256 public totalFlashLoanFeesFirstToken;
    uint256 public totalFlashLoanFeesSecondToken;

    uint8 private locked;

    // Anti-wash-trading protections
    uint256 public constant MINIMUM_TRADE_AMOUNT = 1000; // Prevents dust trades
    mapping(address => uint256) public lastTradeBlock;
    uint256 public constant TRADE_COOLDOWN = 1; // 1 block between trades
    mapping(address => bool) private activeFlashLoan;
    uint256 public constant MAX_PRICE_IMPACT = 500; // 5% max (500/10000)
    mapping(address => bool) public lastTradeDirection; // true = first→second

    struct TradeHistory {
        uint256 totalVolume;
        uint256 tradeCount;
        uint256 lastResetBlock;
    }
    mapping(address => TradeHistory) public tradeHistory;
    uint256 public constant HISTORY_RESET_BLOCKS = 100;
    uint256 public constant MAX_TRADES_PER_PERIOD = 50;

    // Global price impact limits (FIX #3)
    uint256 public lastBlockTraded;
    uint256 public blockTotalPriceImpact;
    uint256 public constant MAX_BLOCK_PRICE_IMPACT = 1000; // 10% max per block (1000/10000)

    // Minimum liquidity lock (FIX #2)
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    modifier nonReentrant() {
        require(locked == 0, "No re-entrancy");
        locked = 1;
        _;
        locked = 0;
    }

    event Swap(
        address indexed user,
        address tokenSwapped,
        uint256 amountSwapped,
        address tokenReceived,
        uint256 amountReceived,
        uint256 newFirstTokenReserve,
        uint256 newSecondTokenReserve,
        uint256 timestamp
    );

    event AddLiquidity(
        address indexed provider,
        uint256 firstTokenAmount,
        uint256 secondTokenAmount,
        uint256 liquiditySharestoMint,
        uint256 timestamp
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 sharesRedeemed,
        uint256 firstTokenAmount,
        uint256 secondTokenAmount,
        uint256 timestamp
    );

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    event SuspiciousActivity(
        address indexed trader,
        string reason,
        uint256 timestamp
    );

    constructor(Token _firstToken, Token _secondToken) {
        firstToken = _firstToken;
        secondToken = _secondToken;
    }

    function addLiquidity(uint256 _firstTokenAmount, uint256 _secondTokenAmount) external nonReentrant {
        require(
            firstToken.transferFrom(msg.sender, address(this), _firstTokenAmount),
            "Failed to transfer firstToken"
        );
        require(
            secondToken.transferFrom(msg.sender, address(this), _secondTokenAmount),
            "Failed to transfer secondToken"
        );

        uint256 liquiditySharestoMint;

        if (totalSharesCirculating == 0) {
            // FIX #2: Minimum liquidity lock
            require(_firstTokenAmount >= MINIMUM_LIQUIDITY, "Insufficient initial liquidity for first token");
            require(_secondTokenAmount >= MINIMUM_LIQUIDITY, "Insufficient initial liquidity for second token");

            // Calculate shares based on geometric mean
            liquiditySharestoMint = sqrt(_firstTokenAmount * _secondTokenAmount);

            // Permanently lock MINIMUM_LIQUIDITY shares to address(0)
            // This prevents price manipulation attacks on initial liquidity
            require(liquiditySharestoMint > MINIMUM_LIQUIDITY, "Initial liquidity too low");

            unchecked {
                firstTokenReserve += _firstTokenAmount;
                secondTokenReserve += _secondTokenAmount;
                totalSharesCirculating = liquiditySharestoMint;
                userLiquidityShares[address(0)] = MINIMUM_LIQUIDITY;
                userLiquidityShares[msg.sender] = liquiditySharestoMint - MINIMUM_LIQUIDITY;
            }
        } else {
            uint256 proportionalSharesFromFirstToken = (totalSharesCirculating * _firstTokenAmount) / firstTokenReserve;
            uint256 proportionalSharesFromSecondToken = (totalSharesCirculating * _secondTokenAmount) / secondTokenReserve;

            require(
                (proportionalSharesFromFirstToken / 1000) == (proportionalSharesFromSecondToken / 1000),
                "Must provide tokens in current pool ratio"
            );
            liquiditySharestoMint = proportionalSharesFromFirstToken;

            unchecked {
                firstTokenReserve += _firstTokenAmount;
                secondTokenReserve += _secondTokenAmount;
                totalSharesCirculating += liquiditySharestoMint;
                userLiquidityShares[msg.sender] += liquiditySharestoMint;
            }
        }

        constantProductK = firstTokenReserve * secondTokenReserve;

        emit AddLiquidity(msg.sender, _firstTokenAmount, _secondTokenAmount, liquiditySharestoMint, block.timestamp);
    }

    function calculateSecondTokenDeposit(uint256 _secondTokenAmount) public view returns (uint256) {
        require(_secondTokenAmount > 0 && secondTokenReserve > 0, "Invalid amount or pool not initialized");
        return (firstTokenReserve * _secondTokenAmount) / secondTokenReserve;
    }

    function calculateFirstTokenDeposit(uint256 _firstTokenAmount) public view returns (uint256) {
        require(_firstTokenAmount > 0 && firstTokenReserve > 0, "Invalid amount or pool not initialized");
        return (secondTokenReserve * _firstTokenAmount) / firstTokenReserve;
    }

    function calculateFirstTokenSwap(uint256 _firstTokenAmount) public view returns (uint256 secondTokenOut) {
        require(_firstTokenAmount > 0 && constantProductK > 0, "Invalid swap or pool not initialized");

        uint256 amountInWithFee = (_firstTokenAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 firstTokenAfterSwap = firstTokenReserve + amountInWithFee;
        uint256 secondTokenAfterSwap = constantProductK / firstTokenAfterSwap;
        secondTokenOut = secondTokenReserve - secondTokenAfterSwap;

        if (secondTokenOut == secondTokenReserve) {
            secondTokenOut--;
        }

        require(secondTokenOut < secondTokenReserve, "Swap too large");
    }

    function swapFirstToken(
        uint256 _firstTokenAmount,
        uint256 _minAmountOut,  // FIX #1: Slippage protection
        uint256 _deadline        // FIX #1: Transaction deadline
    ) external nonReentrant returns (uint256 secondTokenOutput) {
        // FIX #1: Check deadline
        require(block.timestamp <= _deadline, "Transaction expired");

        // Anti-wash-trading protections
        require(_firstTokenAmount >= MINIMUM_TRADE_AMOUNT, "Trade too small");
        require(block.number > lastTradeBlock[msg.sender] + TRADE_COOLDOWN, "Trade cooldown active");
        require(!activeFlashLoan[msg.sender], "Cannot trade during flashloan");

        // Check per-address price impact
        uint256 priceImpact = (_firstTokenAmount * 10000) / firstTokenReserve;
        require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");

        // FIX #3: Global price impact limit per block
        if (block.number > lastBlockTraded) {
            blockTotalPriceImpact = 0;
            lastBlockTraded = block.number;
        }
        blockTotalPriceImpact += priceImpact;
        require(blockTotalPriceImpact <= MAX_BLOCK_PRICE_IMPACT, "Block price impact exceeded");

        // Prevent immediate reverse trades in same block
        if (lastTradeBlock[msg.sender] == block.number && !lastTradeDirection[msg.sender]) {
            emit SuspiciousActivity(msg.sender, "Reverse trade in same block", block.timestamp);
            revert("No reverse trades in same block");
        }

        // Record trade
        _recordTrade(msg.sender, _firstTokenAmount);

        secondTokenOutput = calculateFirstTokenSwap(_firstTokenAmount);

        // FIX #1: Slippage protection
        require(secondTokenOutput >= _minAmountOut, "Slippage tolerance exceeded");

        require(firstToken.transferFrom(msg.sender, address(this), _firstTokenAmount), "Transfer failed");

        unchecked {
            firstTokenReserve += _firstTokenAmount;
            secondTokenReserve -= secondTokenOutput;
        }

        secondToken.transfer(msg.sender, secondTokenOutput);

        // Update tracking
        lastTradeBlock[msg.sender] = block.number;
        lastTradeDirection[msg.sender] = true;

        emit Swap(
            msg.sender,
            address(firstToken),
            _firstTokenAmount,
            address(secondToken),
            secondTokenOutput,
            firstTokenReserve,
            secondTokenReserve,
            block.timestamp
        );
    }


    function calculateSecondTokenSwap(uint256 _secondTokenAmount) public view returns (uint256 firstTokenOut) {
        require(_secondTokenAmount > 0 && constantProductK > 0, "Invalid swap or pool not initialized");

        uint256 amountInWithFee = (_secondTokenAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 secondTokenAfterSwap = secondTokenReserve + amountInWithFee;
        uint256 firstTokenAfterSwap = constantProductK / secondTokenAfterSwap;
        firstTokenOut = firstTokenReserve - firstTokenAfterSwap;

        if (firstTokenOut == firstTokenReserve) {
            firstTokenOut--;
        }

        require(firstTokenOut < firstTokenReserve, "Swap too large");
    }

    function swapSecondToken(
        uint256 _secondTokenAmount,
        uint256 _minAmountOut,  // FIX #1: Slippage protection
        uint256 _deadline        // FIX #1: Transaction deadline
    ) external nonReentrant returns (uint256 firstTokenOutput) {
        // FIX #1: Check deadline
        require(block.timestamp <= _deadline, "Transaction expired");

        // Anti-wash-trading protections
        require(_secondTokenAmount >= MINIMUM_TRADE_AMOUNT, "Trade too small");
        require(block.number > lastTradeBlock[msg.sender] + TRADE_COOLDOWN, "Trade cooldown active");
        require(!activeFlashLoan[msg.sender], "Cannot trade during flashloan");

        // Check per-address price impact
        uint256 priceImpact = (_secondTokenAmount * 10000) / secondTokenReserve;
        require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");

        // FIX #3: Global price impact limit per block
        if (block.number > lastBlockTraded) {
            blockTotalPriceImpact = 0;
            lastBlockTraded = block.number;
        }
        blockTotalPriceImpact += priceImpact;
        require(blockTotalPriceImpact <= MAX_BLOCK_PRICE_IMPACT, "Block price impact exceeded");

        // Prevent immediate reverse trades in same block
        if (lastTradeBlock[msg.sender] == block.number && lastTradeDirection[msg.sender]) {
            emit SuspiciousActivity(msg.sender, "Reverse trade in same block", block.timestamp);
            revert("No reverse trades in same block");
        }

        // Record trade
        _recordTrade(msg.sender, _secondTokenAmount);

        firstTokenOutput = calculateSecondTokenSwap(_secondTokenAmount);

        // FIX #1: Slippage protection
        require(firstTokenOutput >= _minAmountOut, "Slippage tolerance exceeded");

        require(secondToken.transferFrom(msg.sender, address(this), _secondTokenAmount), "Transfer failed");

        unchecked {
            secondTokenReserve += _secondTokenAmount;
            firstTokenReserve -= firstTokenOutput;
        }

        firstToken.transfer(msg.sender, firstTokenOutput);

        // Update tracking
        lastTradeBlock[msg.sender] = block.number;
        lastTradeDirection[msg.sender] = false;

        emit Swap(
            msg.sender,
            address(secondToken),
            _secondTokenAmount,
            address(firstToken),
            firstTokenOutput,
            firstTokenReserve,
            secondTokenReserve,
            block.timestamp
        );
    }

    function removeLiquidity(uint256 _sharesToWithdraw) external nonReentrant returns (uint256 firstTokenAmount, uint256 secondTokenAmount) {
        require(
            _sharesToWithdraw > 0 && _sharesToWithdraw <= userLiquidityShares[msg.sender],
            "Invalid shares amount"
        );

        firstTokenAmount = (_sharesToWithdraw * firstTokenReserve) / totalSharesCirculating;
        secondTokenAmount = (_sharesToWithdraw * secondTokenReserve) / totalSharesCirculating;

        unchecked {
            totalSharesCirculating -= _sharesToWithdraw;
            userLiquidityShares[msg.sender] -= _sharesToWithdraw;
            firstTokenReserve -= firstTokenAmount;
            secondTokenReserve -= secondTokenAmount;
        }

        constantProductK = firstTokenReserve * secondTokenReserve;

        require(firstToken.transfer(msg.sender, firstTokenAmount), "Transfer failed");
        require(secondToken.transfer(msg.sender, secondTokenAmount), "Transfer failed");

        emit RemoveLiquidity(msg.sender, _sharesToWithdraw, firstTokenAmount, secondTokenAmount, block.timestamp);
    }

    function calculateFlashLoanFee(uint256 _amount) public pure returns (uint256) {
        return (_amount * FLASHLOAN_FEE_NUMERATOR) / FLASHLOAN_FEE_DENOMINATOR;
    }

    function flashLoanFirstToken(uint256 _amount, bytes calldata _params) external nonReentrant {
        require(_amount > 0 && _amount <= firstTokenReserve, "Invalid flashloan amount");

        uint256 balanceBefore = firstToken.balanceOf(address(this));
        uint256 fee = calculateFlashLoanFee(_amount);

        // Mark flashloan as active to prevent self-trading
        activeFlashLoan[msg.sender] = true;

        require(firstToken.transfer(msg.sender, _amount), "Flashloan transfer failed");

        require(
            IFlashLoanReceiver(msg.sender).executeOperation(
                address(firstToken),
                _amount,
                fee,
                msg.sender,
                _params
            ),
            "Flashloan execution failed"
        );

        uint256 balanceAfter = firstToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flashloan not repaid");

        unchecked {
            totalFlashLoanFeesFirstToken += fee;
            firstTokenReserve += fee;
        }

        // Clear flashloan flag
        activeFlashLoan[msg.sender] = false;

        emit FlashLoan(msg.sender, address(firstToken), _amount, fee, block.timestamp);
    }

    function flashLoanSecondToken(uint256 _amount, bytes calldata _params) external nonReentrant {
        require(_amount > 0 && _amount <= secondTokenReserve, "Invalid flashloan amount");

        uint256 balanceBefore = secondToken.balanceOf(address(this));
        uint256 fee = calculateFlashLoanFee(_amount);

        // Mark flashloan as active to prevent self-trading
        activeFlashLoan[msg.sender] = true;

        require(secondToken.transfer(msg.sender, _amount), "Flashloan transfer failed");

        require(
            IFlashLoanReceiver(msg.sender).executeOperation(
                address(secondToken),
                _amount,
                fee,
                msg.sender,
                _params
            ),
            "Flashloan execution failed"
        );

        uint256 balanceAfter = secondToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flashloan not repaid");

        unchecked {
            totalFlashLoanFeesSecondToken += fee;
            secondTokenReserve += fee;
        }

        // Clear flashloan flag
        activeFlashLoan[msg.sender] = false;

        emit FlashLoan(msg.sender, address(secondToken), _amount, fee, block.timestamp);
    }

    function getMaxFlashLoanFirstToken() external view returns (uint256) {
        return firstTokenReserve;
    }

    function getMaxFlashLoanSecondToken() external view returns (uint256) {
        return secondTokenReserve;
    }

    // Internal function to record trade history and detect wash trading
    function _recordTrade(address trader, uint256 amount) internal {
        TradeHistory storage history = tradeHistory[trader];

        // Reset history if period expired
        if (block.number > history.lastResetBlock + HISTORY_RESET_BLOCKS) {
            history.totalVolume = 0;
            history.tradeCount = 0;
            history.lastResetBlock = block.number;
        }

        unchecked {
            history.totalVolume += amount;
            history.tradeCount += 1;
        }

        // Flag suspicious high-frequency trading
        if (history.tradeCount > MAX_TRADES_PER_PERIOD) {
            emit SuspiciousActivity(trader, "Excessive trades in period", block.timestamp);
            revert("Too many trades in period");
        }
    }

    // Babylonian method for square root calculation
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
