// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

import "../../interfaces/IMuxGetter.sol";
import "./lib/LibMux.sol";

import "./Storage.sol";
import "./Types.sol";

contract Positions is Storage{
    //ToDo - look into the whole uint64 to bytes32 conversion and see if there is a way pending orders can be saved as uint64.
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    uint256 internal constant MAX_PENDING_ORDERS = 64;

    event AddPendingOrder(
        LibMux.OrderCategory category,
        uint256 index,
        uint256 timestamp
    );
    event RemovePendingOrder(uint64 orderId);
    event CancelOrder(uint64 orderId, bool success);

    event OpenPosition(address collateralToken, address indexToken, bool isLong, PositionContext context);
    event ClosePosition(address collateralToken, address indexToken, bool isLong, PositionContext context);

    function _hasPendingOrder(uint64 key) internal view returns (bool) {
        return _pendingOrders.contains(bytes32(uint256(key)));
    }

    function _getPendingOrders() internal view returns (bytes32[] memory) {
        return _pendingOrders.values();
    }

    function _removePendingOrder(uint64 key) internal {
        _pendingOrders.remove(bytes32(uint256(key)));
        emit RemovePendingOrder(key);
    }

    function _addPendingOrder(
        LibMux.OrderCategory category,
        uint256 startOrderCount,
        uint256 endOrderCount,
        bytes32 subAccountId
    ) internal{
        (bytes32[3][] memory orderArray, uint256 totalCount) = IMuxOrderBook(_exchangeConfigs.orderBook).getOrders(startOrderCount, endOrderCount);
        for (uint256 i = 0; i < totalCount; i++) {
            PositionOrder memory order = LibMux.decodePositionOrder(orderArray[i]);
            if(order.subAccountId == subAccountId) {
                require(
                    _pendingOrders.add(bytes32(uint256(order.id))),
                    "AddFailed"
                );
                emit AddPendingOrder(category, i, block.timestamp);
                break;
            }
        }
    }

    function _isMarginSafe(SubAccount memory subAccount, uint96 collateralPrice, uint96 assetPrice, bool isLong, bool isOpen) internal view returns(bool){
        //ToDo - double check if the following calculations are solid.
        if(subAccount.size == 0){
            return true;
        }
        Asset memory asset = IMuxGetter(_exchangeConfigs.liquidityPool).getAssetInfo(_assetConfigs.id);
        bool hasProfit = false;
        uint96 muxPnlUsd = 0;
        uint96 muxFundingFeeUsd = 0;
        if (subAccount.size != 0) {
            if (subAccount.size != 0) {
                //ToDo - should we add deltaSize and deltaCollateralAmount to subAccount.size below?
                (hasProfit, muxPnlUsd) = LibMux._positionPnlUsd(asset, subAccount, isLong, subAccount.size, assetPrice); 
                muxFundingFeeUsd = LibMux._getFundingFeeUsd(subAccount, asset, isLong, assetPrice);
            }
        }
        uint32 threshold = isOpen ? asset.initialMarginRate : asset.maintenanceMarginRate;
        return LibMux._isAccountSafe(subAccount, collateralPrice, assetPrice, threshold, hasProfit, muxPnlUsd, muxFundingFeeUsd);
    }

    function _placePositionOrder(PositionContext memory context) internal{
        require(_pendingOrders.length() <= MAX_PENDING_ORDERS, "TooManyPendingOrders");

        SubAccount memory subAccount;
        (subAccount.collateral, subAccount.size, subAccount.lastIncreasedTime, subAccount.entryPrice, subAccount.entryFunding) = IMuxGetter(_exchangeConfigs.liquidityPool).getSubAccount(context.subAccountId);

        bool isOpen = (context.flags & POSITION_OPEN != 0) ? true : false;

        require(
            _isMarginSafe(
                subAccount,
                context.collateralPrice,
                context.assetPrice,
                context.isLong,
                isOpen
            ),
            "ImMarginUnsafe"
        );

        uint256 startOrderCount = IMuxOrderBook(_exchangeConfigs.orderBook).getOrderCount();
        IMuxOrderBook(_exchangeConfigs.orderBook).placePositionOrder3(context.subAccountId, context.collateralAmount, context.size, context.price, context.profitTokenId ,context.flags, context.deadline, _exchangeConfigs.referralCode, context.extra);
        uint256 endOrderCount = IMuxOrderBook(_exchangeConfigs.orderBook).getOrderCount();

        require(endOrderCount > startOrderCount, "Order not recorded on MUX");

        _addPendingOrder(LibMux.OrderCategory.OPEN, startOrderCount, endOrderCount, context.subAccountId);
        emit OpenPosition(_account.collateralToken, _account.indexToken, context.isLong, context);
    }

    function _cancelOrder(uint64 orderId) internal returns(bool success){
        require(_hasPendingOrder(orderId), "KeyNotExists");
        success = LibMux.cancelOrder(_exchangeConfigs, orderId);
        _removePendingOrder(orderId);
        emit CancelOrder(orderId, success);
    }

}