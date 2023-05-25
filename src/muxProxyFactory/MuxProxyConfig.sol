// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "./MuxStorage.sol";

contract MuxProxyConfig is MuxStorage{

    event SetExchangeConfig(uint256 ExchangeId, uint256[] values, uint256 version);
    event SetExchangeAssetConfig(uint256 ExchangeId, address assetToken, uint256[] values, uint256 version);

    function _getLatestVersions(uint256 ExchangeId, address assetToken)
        internal
        view
        returns (uint32 ExchangeConfigVersion, uint32 assetConfigVersion)
    {
        ExchangeConfigVersion = _exchangeConfigs[ExchangeId].version;
        assetConfigVersion = _exchangeAssetConfigs[ExchangeId][assetToken].version;
    }

    function _setExchangeConfig(uint256 ExchangeId, uint256[] memory values) internal {
        _exchangeConfigs[ExchangeId].values = values;
        _exchangeConfigs[ExchangeId].version += 1;
        emit SetExchangeConfig(ExchangeId, values, _exchangeConfigs[ExchangeId].version);
    }

    function _setExchangeAssetConfig(
        uint256 ExchangeId,
        address assetToken,
        uint256[] memory values
    ) internal {
        _exchangeAssetConfigs[ExchangeId][assetToken].values = values;
        _exchangeAssetConfigs[ExchangeId][assetToken].version += 1;
        emit SetExchangeAssetConfig(ExchangeId, assetToken, values, _exchangeAssetConfigs[ExchangeId][assetToken].version);
    }
}