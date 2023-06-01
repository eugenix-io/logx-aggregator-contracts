// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

import "../../interfaces/IGmxProxyFactory.sol";

import "../lib/LibUtils.sol";
import "./Storage.sol";
import "./Position.sol";

contract Config is Storage, Position{
    using LibUtils for bytes32;
    using LibUtils for address;
    using LibUtils for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    function _updateConfigs() internal virtual{
        address token = _account.indexToken;
        (uint32 latestexchangeVersion, uint32 latestAssetVersion) = IGmxProxyFactory(_factory).getConfigVersions(
            EXCHANGE_ID,
            token
        );
        if (_localexchangeVersion < latestexchangeVersion) {
            _updateexchangeConfigs();
            _localexchangeVersion = latestexchangeVersion;
        }
        // pull configs from factory
        if (_localAssetVersions[token] < latestAssetVersion) {
            _updateAssetConfigs();
            _localAssetVersions[token] = latestAssetVersion;
        }
        _patch();
    }

    function _updateexchangeConfigs() internal {
        uint256[] memory values = IGmxProxyFactory(_factory).getExchangeConfig(EXCHANGE_ID);
        require(values.length >= uint256(ExchangeConfigIds.END), "MissingConfigs");

        address newPositionRouter = values[uint256(ExchangeConfigIds.POSITION_ROUTER)].toAddress();
        address newOrderBook = values[uint256(ExchangeConfigIds.ORDER_BOOK)].toAddress();
        //ToDo - is cancelling orders when we change positionRouter and orderBook really necessary?
        _onGmxAddressUpdated(
            _exchangeConfigs.positionRouter,
            _exchangeConfigs.orderBook,
            newPositionRouter,
            newOrderBook
        );
        _exchangeConfigs.vault = values[uint256(ExchangeConfigIds.VAULT)].toAddress();
        _exchangeConfigs.positionRouter = newPositionRouter;
        _exchangeConfigs.orderBook = newOrderBook;
        _exchangeConfigs.router = values[uint256(ExchangeConfigIds.ROUTER)].toAddress();
        _exchangeConfigs.referralCode = bytes32(values[uint256(ExchangeConfigIds.REFERRAL_CODE)]);
        _exchangeConfigs.marketOrderTimeoutSeconds = values[uint256(ExchangeConfigIds.MARKET_ORDER_TIMEOUT_SECONDS)]
            .toU32();
        _exchangeConfigs.limitOrderTimeoutSeconds = values[uint256(ExchangeConfigIds.LIMIT_ORDER_TIMEOUT_SECONDS)]
            .toU32();
    }

    function _onGmxAddressUpdated(
        address previousPositionRouter,
        address previousOrderBook,
        address newPostitionRouter,
        address newOrderBook
    ) internal virtual {
        bool cancelPositionRouter = previousPositionRouter != newPostitionRouter;
        bool cancelOrderBook = previousOrderBook != newOrderBook;
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            if (cancelPositionRouter) {
                LibGmx.cancelOrderFromPositionRouter(previousPositionRouter, key);
                _removePendingOrder(key);
            }
            if (cancelOrderBook) {
                LibGmx.cancelOrderFromOrderBook(newOrderBook, key);
                _removePendingOrder(key);
            }
        }
    }

    function _updateAssetConfigs() internal {
        uint256[] memory values = IGmxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.collateralToken);
        require(values.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _assetConfigs.initialMarginRate = values[uint256(TokenConfigIds.INITIAL_MARGIN_RATE)].toU32();
        _assetConfigs.maintenanceMarginRate = values[uint256(TokenConfigIds.MAINTENANCE_MARGIN_RATE)].toU32();
        _assetConfigs.liquidationFeeRate = values[uint256(TokenConfigIds.LIQUIDATION_FEE_RATE)].toU32();
        _assetConfigs.referrenceOracle = values[uint256(TokenConfigIds.REFERRENCE_ORACLE)].toAddress();
        _assetConfigs.referenceDeviation = values[uint256(TokenConfigIds.REFERRENCE_ORACLE_DEVIATION)].toU32();
    }

    // path  ToDo: remove me when deploy?
    function _patch() internal {
        if (_account.collateralDecimals == 0) {
            _account.collateralDecimals = IERC20MetadataUpgradeable(_account.collateralToken).decimals();
        }
    }
}