// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IGmxRouter.sol";
import "../../interfaces/IGmxProxyFactory.sol";

import "../../components/ImplementationGuard.sol";
import "./Storage.sol";
import "./Config.sol";
import "./Position.sol";

contract GMXAdapter is Position, Config, ImplementationGuard, ReentrancyGuardUpgradeable{
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    address internal immutable _WETH;

    constructor(address weth) ImplementationGuard() {
        _WETH = weth;
    }

    receive() external payable {}

    modifier onlyTraderOrFactory() {
        require(msg.sender == _account.account || msg.sender == _factory, "OnlyTraderOrFactory");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory, "onlyFactory");
        _;
    }

    function initialize(
        uint256 exchangeId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(exchangeId == EXCHANGE_ID, "Invalidexchange");

        _factory = msg.sender;
        _gmxPositionKey = keccak256(abi.encodePacked(address(this), collateralToken, assetToken, isLong));
        _account.account = account;
        _account.collateralToken = collateralToken;
        _account.indexToken = assetToken;
        _account.isLong = isLong;
        _account.collateralDecimals = IERC20MetadataUpgradeable(collateralToken).decimals();
        _updateConfigs();
    }

    function accountState() external view returns (AccountState memory) {
        return _account;
    }

    function getPendingOrderKeys() external view returns (bytes32[] memory) {
        return _getPendingOrders();
    }

    function _tryApprovePlugins() internal {
        IGmxRouter(_exchangeConfigs.router).approvePlugin(_exchangeConfigs.orderBook);
        IGmxRouter(_exchangeConfigs.router).approvePlugin(_exchangeConfigs.positionRouter);
    }

    function _cleanOrders() internal {
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            (bool notExist, ) = LibGmx.getOrder(_exchangeConfigs, key);
            if (notExist) {
                _removePendingOrder(key);
            }
        }
    }

    function _isMarketOrder(uint8 flags) internal pure returns (bool) {
        return (flags & POSITION_MARKET_ORDER) != 0;
    }

    /// @notice Place a openning request on GMX.
    /// - market order => positionRouter
    /// - limit order => orderbook
    /// token: swapInToken(swapInAmount) => _account.collateralToken => _account.indexToken.
    function openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _tryApprovePlugins();
        _cleanOrders();

        OpenPositionContext memory context = OpenPositionContext({
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            fee: 0,
            amountIn: 0,
            amountOut: 0,
            gmxOrderIndex: 0,
            executionFee: msg.value
        });
        if (swapInToken == _WETH) {
            IWETH(_WETH).deposit{ value: swapInAmount }();
            context.executionFee = msg.value - swapInAmount;
        }
        if (swapInToken != _account.collateralToken) {
            context.amountOut = LibGmx.swap(
                _exchangeConfigs,
                swapInToken,
                _account.collateralToken,
                swapInAmount,
                minSwapOut
            );
        } else {
            context.amountOut = swapInAmount;
        }
        context.amountIn = context.amountOut;
        IERC20Upgradeable(_account.collateralToken).approve(_exchangeConfigs.router, context.amountIn);

        _openPosition(context);
    }

    /// @notice Place a closing request on GMX.
    function closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _cleanOrders();

        ClosePositionContext memory context = ClosePositionContext({
            collateralUsd: collateralUsd * GMX_DECIMAL_MULTIPLIER,
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            gmxOrderIndex: 0
        });
        _closePosition(context);
    }

    function cancelOrders(bytes32[] memory keys) external onlyTraderOrFactory nonReentrant {
        _cleanOrders();
        _cancelOrders(keys);
    }

    function _cancelOrders(bytes32[] memory keys) internal {
        for (uint256 i = 0; i < keys.length; i++) {
            bool success = _cancelOrder(keys[i]);
            require(success, "CancelFailed");
        }
    }

    function cancelTimeoutOrders(bytes32[] memory keys) external nonReentrant {
        _cleanOrders();
        _cancelTimeoutOrders(keys);
    }

    function _cancelTimeoutOrders(bytes32[] memory keys) internal {
        uint256 _now = block.timestamp;
        uint256 marketTimeout = _exchangeConfigs.marketOrderTimeoutSeconds;
        uint256 limitTimeout = _exchangeConfigs.limitOrderTimeoutSeconds;
        for (uint256 i = 0; i < keys.length; i++) {
            LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(keys[i]);
            uint256 elapsed = _now - history.timestamp;
            if (
                ((history.receiver == LibGmx.OrderReceiver.PR_INC || history.receiver == LibGmx.OrderReceiver.PR_DEC) &&
                    elapsed >= marketTimeout) ||
                ((history.receiver == LibGmx.OrderReceiver.OB_INC || history.receiver == LibGmx.OrderReceiver.OB_DEC) &&
                    elapsed >= limitTimeout)
            ) {
                _cancelOrder(keys[i]);
            }
        }
    }
}