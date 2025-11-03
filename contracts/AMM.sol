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
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee,
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
            liquiditySharestoMint = 100 * PRECISION;
        } else {
            uint256 proportionalSharesFromFirstToken = (totalSharesCirculating * _firstTokenAmount) / firstTokenReserve;
            uint256 proportionalSharesFromSecondToken = (totalSharesCirculating * _secondTokenAmount) / secondTokenReserve;

            require(
                (proportionalSharesFromFirstToken / 1000) == (proportionalSharesFromSecondToken / 1000),
                "Must provide tokens in current pool ratio"
            );
            liquiditySharestoMint = proportionalSharesFromFirstToken;
        }

        unchecked {
            firstTokenReserve += _firstTokenAmount;
            secondTokenReserve += _secondTokenAmount;
            totalSharesCirculating += liquiditySharestoMint;
            userLiquidityShares[msg.sender] += liquiditySharestoMint;
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

    function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256 secondTokenOutput) {
        secondTokenOutput = calculateFirstTokenSwap(_firstTokenAmount);

        require(firstToken.transferFrom(msg.sender, address(this), _firstTokenAmount), "Transfer failed");

        unchecked {
            firstTokenReserve += _firstTokenAmount;
            secondTokenReserve -= secondTokenOutput;
        }

        secondToken.transfer(msg.sender, secondTokenOutput);

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

    function swapSecondToken(uint256 _secondTokenAmount) external nonReentrant returns (uint256 firstTokenOutput) {
        firstTokenOutput = calculateSecondTokenSwap(_secondTokenAmount);

        require(secondToken.transferFrom(msg.sender, address(this), _secondTokenAmount), "Transfer failed");

        unchecked {
            secondTokenReserve += _secondTokenAmount;
            firstTokenReserve -= firstTokenOutput;
        }

        firstToken.transfer(msg.sender, firstTokenOutput);

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

    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        require(token == address(firstToken) || token == address(secondToken), "Invalid token");
        
        uint256 fee = (amount * 5) / 10000; // 0.05% fee
        uint256 balanceBefore = Token(token).balanceOf(address(this));
        
        require(balanceBefore >= amount, "Insufficient liquidity");
        
        // Send tokens to borrower
        Token(token).transfer(msg.sender, amount);
        
        // Call borrower's callback
        IFlashLoanReceiver(msg.sender).executeOperation(token, amount, fee, data);
        
        // Check repayment
        uint256 balanceAfter = Token(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flashloan not repaid");
        
        emit FlashLoan(msg.sender, token, amount, fee, block.timestamp);
    }
}

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

    function calculateFlashLoanFee(uint256 _amount) public pure returns (uint256) {
        return (_amount * FLASHLOAN_FEE_NUMERATOR) / FLASHLOAN_FEE_DENOMINATOR;
    }

    function flashLoanFirstToken(uint256 _amount, bytes calldata _params) external nonReentrant {
        require(_amount > 0 && _amount <= firstTokenReserve, "Invalid flashloan amount");

        uint256 balanceBefore = firstToken.balanceOf(address(this));
        uint256 fee = calculateFlashLoanFee(_amount);

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

        emit FlashLoan(msg.sender, address(firstToken), _amount, fee, block.timestamp);
    }

    function flashLoanSecondToken(uint256 _amount, bytes calldata _params) external nonReentrant {
        require(_amount > 0 && _amount <= secondTokenReserve, "Invalid flashloan amount");

        uint256 balanceBefore = secondToken.balanceOf(address(this));
        uint256 fee = calculateFlashLoanFee(_amount);

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

        emit FlashLoan(msg.sender, address(secondToken), _amount, fee, block.timestamp);
    }

    function getMaxFlashLoanFirstToken() external view returns (uint256) {
        return firstTokenReserve;
    }

    function getMaxFlashLoanSecondToken() external view returns (uint256) {
        return secondTokenReserve;
    }
}
