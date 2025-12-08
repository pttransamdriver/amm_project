// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/Token.sol";
import "../core/AMM.sol";
import "./IFlashLoanReceiver.sol";
import "../interfaces/IAavePool.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IBalancerVault.sol";

/**
 * @title FlashLoanHub
 * @notice Aggregates flashloan functionality from multiple DEX protocols
 * @dev Supports Aave V3, Uniswap V3, Balancer V2, and custom AMM flashloans
 */
contract FlashLoanHub is 
    IFlashLoanReceiver,
    IFlashLoanSimpleReceiver,
    IUniswapV3FlashCallback,
    IBalancerFlashLoanRecipient 
{
    enum FlashLoanProvider {
        CUSTOM_AMM,
        AAVE_V3,
        UNISWAP_V3,
        BALANCER_V2
    }

    address public immutable owner;
    AutomatedMarketMaker public customAMM;
    IAavePool public aavePool;
    IBalancerVault public balancerVault;

    // FIX #4: Strategy whitelist for security
    mapping(address => bool) public approvedStrategies;

    struct FlashLoanParams {
        FlashLoanProvider provider;
        address strategy;
        bytes strategyData;
    }

    event FlashLoanExecuted(
        FlashLoanProvider indexed provider,
        address indexed token,
        uint256 amount,
        uint256 fee,
        address indexed strategy,
        bool success
    );

    event StrategyApproved(address indexed strategy, bool approved);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _customAMM,
        address _aavePool,
        address _balancerVault
    ) {
        owner = msg.sender;
        customAMM = AutomatedMarketMaker(_customAMM);
        aavePool = IAavePool(_aavePool);
        balancerVault = IBalancerVault(_balancerVault);
    }

    function executeFlashLoan(
        FlashLoanProvider _provider,
        address _token,
        uint256 _amount,
        address _strategy,
        bytes calldata _strategyData
    ) external {
        // FIX #4: Validate strategy is approved
        require(approvedStrategies[_strategy], "Strategy not approved");

        FlashLoanParams memory params = FlashLoanParams({
            provider: _provider,
            strategy: _strategy,
            strategyData: _strategyData
        });

        bytes memory encodedParams = abi.encode(params);

        if (_provider == FlashLoanProvider.CUSTOM_AMM) {
            _executeCustomAMMFlashLoan(_token, _amount, encodedParams);
        } else if (_provider == FlashLoanProvider.AAVE_V3) {
            _executeAaveFlashLoan(_token, _amount, encodedParams);
        } else if (_provider == FlashLoanProvider.UNISWAP_V3) {
            revert("Uniswap V3 requires pool address");
        } else if (_provider == FlashLoanProvider.BALANCER_V2) {
            _executeBalancerFlashLoan(_token, _amount, encodedParams);
        }
    }

    function executeUniswapV3FlashLoan(
        address _pool,
        address _token,
        uint256 _amount,
        address _strategy,
        bytes calldata _strategyData
    ) external {
        // FIX #4: Validate strategy is approved
        require(approvedStrategies[_strategy], "Strategy not approved");

        FlashLoanParams memory params = FlashLoanParams({
            provider: FlashLoanProvider.UNISWAP_V3,
            strategy: _strategy,
            strategyData: _strategyData
        });

        bytes memory encodedParams = abi.encode(params);
        
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        address token0 = pool.token0();
        address token1 = pool.token1();

        if (_token == token0) {
            pool.flash(address(this), _amount, 0, encodedParams);
        } else if (_token == token1) {
            pool.flash(address(this), 0, _amount, encodedParams);
        } else {
            revert("Token not in pool");
        }
    }

    function _executeCustomAMMFlashLoan(
        address _token,
        uint256 _amount,
        bytes memory _params
    ) internal {
        Token firstToken = customAMM.firstToken();
        Token secondToken = customAMM.secondToken();

        if (_token == address(firstToken)) {
            customAMM.flashLoanFirstToken(_amount, _params);
        } else if (_token == address(secondToken)) {
            customAMM.flashLoanSecondToken(_amount, _params);
        } else {
            revert("Token not supported by AMM");
        }
    }

    function _executeAaveFlashLoan(
        address _token,
        uint256 _amount,
        bytes memory _params
    ) internal {
        address[] memory assets = new address[](1);
        assets[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        aavePool.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            _params,
            0
        );
    }

    function _executeBalancerFlashLoan(
        address _token,
        uint256 _amount,
        bytes memory _params
    ) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        balancerVault.flashLoan(address(this), tokens, amounts, _params);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override(IFlashLoanReceiver, IFlashLoanSimpleReceiver) returns (bool) {
        if (msg.sender == address(customAMM)) {
            FlashLoanParams memory flashParams = abi.decode(params, (FlashLoanParams));

            bool success = _executeStrategy(
                flashParams.strategy,
                asset,
                amount,
                premium,
                flashParams.strategyData
            );

            if (success) {
                Token(asset).approve(address(customAMM), amount + premium);
            }

            emit FlashLoanExecuted(
                FlashLoanProvider.CUSTOM_AMM,
                asset,
                amount,
                premium,
                flashParams.strategy,
                success
            );

            return success;
        } else if (msg.sender == address(aavePool)) {
            FlashLoanParams memory flashParams = abi.decode(params, (FlashLoanParams));

            bool success = _executeStrategy(
                flashParams.strategy,
                asset,
                amount,
                premium,
                flashParams.strategyData
            );

            if (success) {
                Token(asset).approve(address(aavePool), amount + premium);
            }

            emit FlashLoanExecuted(
                FlashLoanProvider.AAVE_V3,
                asset,
                amount,
                premium,
                flashParams.strategy,
                success
            );

            return success;
        }

        revert("Invalid caller");
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashLoanParams memory flashParams = abi.decode(data, (FlashLoanParams));
        
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 amount;
        uint256 fee;
        address token;

        if (fee0 > 0) {
            amount = Token(token0).balanceOf(address(this)) - fee0;
            fee = fee0;
            token = token0;
        } else {
            amount = Token(token1).balanceOf(address(this)) - fee1;
            fee = fee1;
            token = token1;
        }

        bool success = _executeStrategy(
            flashParams.strategy,
            token,
            amount,
            fee,
            flashParams.strategyData
        );

        if (success) {
            Token(token).transfer(msg.sender, amount + fee);
        }

        emit FlashLoanExecuted(
            FlashLoanProvider.UNISWAP_V3,
            token,
            amount,
            fee,
            flashParams.strategy,
            success
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(balancerVault), "Invalid caller");
        
        FlashLoanParams memory flashParams = abi.decode(userData, (FlashLoanParams));
        
        bool success = _executeStrategy(
            flashParams.strategy,
            tokens[0],
            amounts[0],
            feeAmounts[0],
            flashParams.strategyData
        );

        if (success) {
            Token(tokens[0]).transfer(msg.sender, amounts[0] + feeAmounts[0]);
        }

        emit FlashLoanExecuted(
            FlashLoanProvider.BALANCER_V2,
            tokens[0],
            amounts[0],
            feeAmounts[0],
            flashParams.strategy,
            success
        );
    }

    function _executeStrategy(
        address _strategy,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes memory _data
    ) internal returns (bool) {
        (bool success, bytes memory result) = _strategy.call(
            abi.encodeWithSignature(
                "execute(address,uint256,uint256,bytes)",
                _token,
                _amount,
                _fee,
                _data
            )
        );

        return success && abi.decode(result, (bool));
    }

    function getFlashLoanFee(
        FlashLoanProvider _provider,
        address _token,
        uint256 _amount
    ) external view returns (uint256) {
        if (_provider == FlashLoanProvider.CUSTOM_AMM) {
            return customAMM.calculateFlashLoanFee(_amount);
        } else if (_provider == FlashLoanProvider.AAVE_V3) {
            uint128 premium = aavePool.FLASHLOAN_PREMIUM_TOTAL();
            return (_amount * premium) / 10000;
        } else if (_provider == FlashLoanProvider.UNISWAP_V3) {
            return 0;
        } else if (_provider == FlashLoanProvider.BALANCER_V2) {
            return 0;
        }
        return 0;
    }

    function getMaxFlashLoan(
        FlashLoanProvider _provider,
        address _token
    ) external view returns (uint256) {
        if (_provider == FlashLoanProvider.CUSTOM_AMM) {
            Token firstToken = customAMM.firstToken();
            Token secondToken = customAMM.secondToken();

            if (_token == address(firstToken)) {
                return customAMM.getMaxFlashLoanFirstToken();
            } else if (_token == address(secondToken)) {
                return customAMM.getMaxFlashLoanSecondToken();
            }
        }
        return 0;
    }

    // FIX #4: Strategy whitelist management functions
    /**
     * @notice Approve a strategy contract for flashloan execution
     * @param _strategy Address of the strategy contract to approve
     */
    function approveStrategy(address _strategy) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy address");
        approvedStrategies[_strategy] = true;
        emit StrategyApproved(_strategy, true);
    }

    /**
     * @notice Revoke approval for a strategy contract
     * @param _strategy Address of the strategy contract to revoke
     */
    function revokeStrategy(address _strategy) external onlyOwner {
        approvedStrategies[_strategy] = false;
        emit StrategyApproved(_strategy, false);
    }

    /**
     * @notice Batch approve multiple strategies
     * @param _strategies Array of strategy addresses to approve
     */
    function batchApproveStrategies(address[] calldata _strategies) external onlyOwner {
        for (uint256 i = 0; i < _strategies.length; i++) {
            require(_strategies[i] != address(0), "Invalid strategy address");
            approvedStrategies[_strategies[i]] = true;
            emit StrategyApproved(_strategies[i], true);
        }
    }

    /**
     * @notice Check if a strategy is approved
     * @param _strategy Address of the strategy to check
     * @return bool True if strategy is approved
     */
    function isStrategyApproved(address _strategy) external view returns (bool) {
        return approvedStrategies[_strategy];
    }

    receive() external payable {}
}

