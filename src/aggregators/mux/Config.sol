// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../../interfaces/IMuxProxyFactory.sol";

import "../lib/LibUtils.sol";
import "./Storage.sol";

contract Config is Storage{
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
        _patch();
    }

    function _updateexchangeConfigs() internal {
        uint256[] memory values = IMuxProxyFactory(_factory).getExchangeConfig(EXCHANGE_ID);
        require(values.length >= uint256(ExchangeConfigIds.END), "MissingConfigs");

        address newLiquidityPool = values[uint256(ExchangeConfigIds.LIQUIDITY_POOL)].toAddress();
        address newOrderBook = values[uint256(ExchangeConfigIds.ORDER_BOOK)].toAddress();

        //ToDo - Do we need onMuxOrderUpdated??

        _exchangeConfigs.liquidityPool = newLiquidityPool;
        _exchangeConfigs.orderBook = newOrderBook;
        _exchangeConfigs.referralCode = bytes32(values[uint256(ExchangeConfigIds.REFERRAL_CODE)]);
        

        //ToDo - do we need market and limit order timeouts here?
    }

    function _updateAssetConfigs() internal {
        uint256[] memory indexValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.indexToken);
        require(indexValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _assetConfigs.id = indexValues[uint256(TokenConfigIds.ID)].toU8();

        uint256[] memory collateralValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.collateralToken);
        require(collateralValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _collateralConfigs.id = collateralValues[uint256(TokenConfigIds.ID)].toU8();

        //ToDo - we do not need anything other than profit token ID here. Should we create a new variable type for profit token ID?
        uint256[] memory profitTokenValues = IMuxProxyFactory(_factory).getExchangeAssetConfig(EXCHANGE_ID, _account.profitToken);
        require(profitTokenValues.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _profitTokenConfigs.id = profitTokenValues[uint256(TokenConfigIds.ID)].toU8();
    }

    // path  ToDo: remove me when deploy?
    function _patch() internal {
        if (_account.collateralDecimals == 0) {
            _account.collateralDecimals = IERC20MetadataUpgradeable(_account.collateralToken).decimals();
        }
    }
}