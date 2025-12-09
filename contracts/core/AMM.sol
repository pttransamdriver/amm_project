// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Token.sol";
import "../flashloan/IFlashLoanReceiver.sol";

contract AutomatedMarketMaker {
    // ============================================
    // STORAGE LAYOUT - OPTIMIZED FOR BYTESTACKING
    // ============================================

    // Slot 0-1: Immutable variables (not in storage)
    Token public immutable firstToken;
    Token public immutable secondToken;

    // Slot 0: Main reserves (can't pack - need full uint256)
    uint256 public firstTokenReserve;

    // Slot 1: Second reserve
    uint256 public secondTokenReserve;

    // Slot 2: Constant product
    uint256 public constantProductK;

    // Slot 3: Total shares
    uint256 public totalSharesCirculating;

    // Slot 4: FlashLoan fees first token
    uint256 public totalFlashLoanFeesFirstToken;

    // Slot 5: FlashLoan fees second token
    uint256 public totalFlashLoanFeesSecondToken;

    // Slot 6: PACKED - State flags and counters (32 bytes total)
    // Using uint128 for block numbers (safe until year ~10^29)
    uint128 public lastBlockTraded;           // 16 bytes - last block with trade
    uint64 public blockTotalPriceImpact;      // 8 bytes - cumulative price impact (max 10000)
    uint32 private _reserved1;                // 4 bytes - reserved for future use
    uint16 private _reserved2;                // 2 bytes - reserved for future use
    uint8 private locked;                     // 1 byte - reentrancy guard
    bool private _reserved3;                  // 1 byte - reserved for future use
    // Total: 32 bytes (1 slot) ✅

    // Mappings (each takes separate slots per key)
    mapping(address => uint256) public userLiquidityShares;
    mapping(address => uint256) public lastTradeBlock;

    // Packed mapping for flags - using uint8 bitmap instead of multiple bool mappings
    // Bit 0: activeFlashLoan
    // Bit 1: lastTradeDirection (0 = second→first, 1 = first→second)
    // Bits 2-7: reserved for future flags
    mapping(address => uint8) private userFlags;

    // Optimized TradeHistory struct - packed into 2 slots instead of 3
    struct TradeHistory {
        uint128 totalVolume;      // 16 bytes - sufficient for most volumes
        uint64 tradeCount;        // 8 bytes - max 18 quintillion trades
        uint64 lastResetBlock;    // 8 bytes - block number
        // Total: 32 bytes (1 slot) ✅
    }
    mapping(address => TradeHistory) public tradeHistory;

    // ============================================
    // CONSTANTS (not stored in contract storage)
    // ============================================
    uint256 private constant PRECISION = 10**18;
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FLASHLOAN_FEE_NUMERATOR = 9;
    uint256 private constant FLASHLOAN_FEE_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_TRADE_AMOUNT = 1000;
    uint256 public constant TRADE_COOLDOWN = 1;
    uint256 public constant MAX_PRICE_IMPACT = 500; // 5% max (500/10000)
    uint256 public constant HISTORY_RESET_BLOCKS = 100;
    uint256 public constant MAX_TRADES_PER_PERIOD = 50;
    uint256 public constant MAX_BLOCK_PRICE_IMPACT = 1000; // 10% max per block
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    // Flag bit positions
    uint8 private constant FLAG_ACTIVE_FLASHLOAN = 0;
    uint8 private constant FLAG_LAST_TRADE_DIRECTION = 1;

    // ============================================
    // HELPER FUNCTIONS FOR BITMAP FLAGS
    // ============================================

    function _getFlag(address user, uint8 flagPosition) private view returns (bool) {
        return (userFlags[user] & (uint8(1) << flagPosition)) != 0;
    }

    function _setFlag(address user, uint8 flagPosition, bool value) private {
        if (value) {
            userFlags[user] |= (uint8(1) << flagPosition);
        } else {
            userFlags[user] &= ~(uint8(1) << flagPosition);
        }
    }

    // Convenience getters for flags (gas-efficient)
    function activeFlashLoan(address user) public view returns (bool) {
        return _getFlag(user, FLAG_ACTIVE_FLASHLOAN);
    }

    function lastTradeDirection(address user) public view returns (bool) {
        return _getFlag(user, FLAG_LAST_TRADE_DIRECTION);
    }

    // ============================================
    // MODIFIERS
    // ============================================

    modifier nonReentrant() {
        require(locked == 0, "No re-entrancy");
        locked = 1;
        _;
        locked = 0;
    }

    // ============================================
    // EVENTS
    // ============================================

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
        require(!_getFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN), "Cannot trade during flashloan");

        // Check per-address price impact
        uint256 priceImpact = (_firstTokenAmount * 10000) / firstTokenReserve;
        require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");

        // FIX #3: Global price impact limit per block
        if (block.number > lastBlockTraded) {
            blockTotalPriceImpact = 0;
            lastBlockTraded = uint128(block.number);
        }
        blockTotalPriceImpact += uint64(priceImpact);
        require(blockTotalPriceImpact <= MAX_BLOCK_PRICE_IMPACT, "Block price impact exceeded");

        // Prevent immediate reverse trades in same block
        if (lastTradeBlock[msg.sender] == block.number && !_getFlag(msg.sender, FLAG_LAST_TRADE_DIRECTION)) {
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
        _setFlag(msg.sender, FLAG_LAST_TRADE_DIRECTION, true);

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
        require(!_getFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN), "Cannot trade during flashloan");

        // Check per-address price impact
        uint256 priceImpact = (_secondTokenAmount * 10000) / secondTokenReserve;
        require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");

        // FIX #3: Global price impact limit per block
        if (block.number > lastBlockTraded) {
            blockTotalPriceImpact = 0;
            lastBlockTraded = uint128(block.number);
        }
        blockTotalPriceImpact += uint64(priceImpact);
        require(blockTotalPriceImpact <= MAX_BLOCK_PRICE_IMPACT, "Block price impact exceeded");

        // Prevent immediate reverse trades in same block
        if (lastTradeBlock[msg.sender] == block.number && _getFlag(msg.sender, FLAG_LAST_TRADE_DIRECTION)) {
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
        _setFlag(msg.sender, FLAG_LAST_TRADE_DIRECTION, false);

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
        _setFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN, true);

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
        _setFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN, false);

        emit FlashLoan(msg.sender, address(firstToken), _amount, fee, block.timestamp);
    }

    function flashLoanSecondToken(uint256 _amount, bytes calldata _params) external nonReentrant {
        require(_amount > 0 && _amount <= secondTokenReserve, "Invalid flashloan amount");

        uint256 balanceBefore = secondToken.balanceOf(address(this));
        uint256 fee = calculateFlashLoanFee(_amount);

        // Mark flashloan as active to prevent self-trading
        _setFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN, true);

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
        _setFlag(msg.sender, FLAG_ACTIVE_FLASHLOAN, false);

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
            history.lastResetBlock = uint64(block.number);
        }

        unchecked {
            history.totalVolume += uint128(amount);
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
