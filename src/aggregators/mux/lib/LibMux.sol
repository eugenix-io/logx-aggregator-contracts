// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../interfaces/IMuxOrderBook.sol";
import "../../lib/LibMath.sol";

import "../Types.sol";

library LibMux {
    using LibMath for uint256;

    enum OrderCategory {
        NONE,
        OPEN,
        CLOSE
    }

    function getOrder(ExchangeConfigs memory exchangeConfigs, uint64 orderId) internal view returns(bytes32[3] memory order, bool isOrderPresent){
        (order, isOrderPresent) = IMuxOrderBook(exchangeConfigs.orderBook).getOrder(orderId);
    }

    function _getFundingFeeUsd(
        SubAccount memory subAccount,
        Asset memory asset,
        bool isLong,
        uint96 assetPrice
    ) internal pure returns (uint96) {
        if (subAccount.size == 0) {
            return 0;
        }
        uint256 cumulativeFunding;
        if (isLong) {
            cumulativeFunding = asset.longCumulativeFundingRate - subAccount.entryFunding;
            cumulativeFunding = cumulativeFunding.wmul(assetPrice);
        } else {
            cumulativeFunding = asset.shortCumulativeFunding - subAccount.entryFunding;
        }
        return cumulativeFunding.wmul(subAccount.size).safeUint96();
    }

    function _positionPnlUsd(
        Asset memory asset,
        SubAccount memory subAccount,
        bool isLong,
        uint96 amount,
        uint96 assetPrice
    ) internal view returns (bool hasProfit, uint96 pnlUsd) {
        if (amount == 0) {
            return (false, 0);
        }
        require(assetPrice > 0, "P=0"); // Price Is Zero
        hasProfit = isLong ? assetPrice > subAccount.entryPrice : assetPrice < subAccount.entryPrice;
        uint96 priceDelta = assetPrice >= subAccount.entryPrice
            ? assetPrice - subAccount.entryPrice
            : subAccount.entryPrice - assetPrice;
        if (
            hasProfit &&
            _blockTimestamp() < subAccount.lastIncreasedTime + asset.minProfitTime &&
            priceDelta < uint256(subAccount.entryPrice).rmul(asset.minProfitRate).safeUint96()
        ) {
            hasProfit = false;
            return (false, 0);
        }
        pnlUsd = uint256(priceDelta).wmul(amount).safeUint96();
    }

    function _isAccountSafe(
        SubAccount memory subAccount,
        uint96 collateralPrice,
        uint96 assetPrice,
        uint32 marginRate,
        bool hasProfit,
        uint96 pnlUsd,
        uint96 fundingFee // fundingFee = 0 if subAccount.collateral was modified
    ) internal pure returns (bool) {
        uint256 thresholdUsd = (uint256(subAccount.size) * uint256(assetPrice) * uint256(marginRate)) / 1e18 / 1e5;
        thresholdUsd += fundingFee;
        uint256 collateralUsd = uint256(subAccount.collateral).wmul(collateralPrice);
        // break down "collateralUsd +/- pnlUsd >= thresholdUsd >= 0"
        if (hasProfit) {
            return collateralUsd + pnlUsd >= thresholdUsd;
        } else {
            return collateralUsd >= thresholdUsd + pnlUsd;
        }
    }

    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }

    // check Types.PositionOrder for schema
    function decodePositionOrder(bytes32[3] memory data) internal pure returns (PositionOrder memory order) {
        order.subAccountId = bytes32(bytes23(data[0]));
        order.collateral = uint96(bytes12(data[2] << 96));
        order.size = uint96(bytes12(data[1]));
        order.flags = uint8(bytes1(data[1] << 104));
        order.price = uint96(bytes12(data[2]));
        order.profitTokenId = uint8(bytes1(data[1] << 96));
        order.expire10s = uint24(bytes3(data[1] << 136));
        order.placeOrderTime = uint32(bytes4(data[1] << 160));
    }

    function cancelOrder(ExchangeConfigs memory _exchangeConfigs, uint64 orderId) internal returns(bool success){
        IMuxOrderBook(_exchangeConfigs.orderBook).cancelOrder(orderId);
        success = true;
    }
}