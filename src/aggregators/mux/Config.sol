// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../../interfaces/IMuxProxyFactory.sol";

import "../lib/LibUtils.sol";
import "./lib/LibMux.sol";
import "./Storage.sol";
import "./Position.sol";

contract Config is Storage, Position{
    using LibUtils for bytes32;
    using LibUtils for address;
    using LibUtils for uint256;

    function _updateConfigs() internal virtual{
        address token = _account.indexToken;
        (uint32 latestexchangeVersion, uint32 latestAssetVersion) = IMuxProxyFactory(_factory).getConfigVersions(
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
    }

    function _updateexchangeConfigs() internal {
        uint256[] memory values = IMuxProxyFactory(_factory).getExchangeConfig(EXCHANGE_ID);
        require(values.length >= uint256(ExchangeConfigIds.END), "MissingConfigs");

        address newLiquidityPool = values[uint256(ExchangeConfigIds.LIQUIDITY_POOL)].toAddress();
        address newOrderBook = values[uint256(ExchangeConfigIds.ORDER_BOOK)].toAddress();

        //ToDo - is cancelling orders when we change orderBook really necessary?
        _onMuxOrderUpdated(_exchangeConfigs.orderBook, newOrderBook);

        _exchangeConfigs.liquidityPool = newLiquidityPool;
        _exchangeConfigs.orderBook = newOrderBook;
        _exchangeConfigs.referralCode = bytes32(values[uint256(ExchangeConfigIds.REFERRAL_CODE)]);
    }

    function _onMuxOrderUpdated(address previousOrderBook, address newOrderBook) internal{
        bool cancelOrderBook = previousOrderBook != newOrderBook;
        uint64[] memory pendingKeys = _pendingOrders;
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            uint64 key = pendingKeys[i];
            if (cancelOrderBook) {
                LibMux.cancelOrderFromOrderBook(newOrderBook, key);
                _removePendingOrder(key);
            }
        }
    }

    function _updateAssetConfigs() internal {
        uint256[] memory indexValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.indexToken);
        require(indexValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _assetConfigs.id = indexValues[uint256(TokenConfigIds.ID)].toU8();

        uint256[] memory collateralValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.collateralToken);
        require(collateralValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _collateralConfigs.id = collateralValues[uint256(TokenConfigIds.ID)].toU8();
    }

    function getTokenId(address tokenAddress) internal view returns(uint8 tokenId){
        uint256[] memory tokenValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, tokenAddress);
        require(tokenValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        tokenId = tokenValues[uint256(TokenConfigIds.ID)].toU8();
    }
}