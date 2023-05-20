// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "./Storage.sol";

contract ProxyConfig is Storage{

    event SetExchangeConfig(uint256 ExchangeId, uint256[] values, uint256 version);
    event SetExchangeAssetConfig(uint256 ExchangeId, address assetToken, uint256[] values, uint256 version);

    function _getLatestVersions(uint256 ExchangeId, address assetToken)
        internal
        view
        returns (uint32 ExchangeConfigVersion, uint32 assetConfigVersion)
    {
        ExchangeConfigVersion = _ExchangeConfigs[ExchangeId].version;
        assetConfigVersion = _ExchangeAssetConfigs[ExchangeId][assetToken].version;
    }

    function _setExchangeConfig(uint256 ExchangeId, uint256[] memory values) internal {
        _ExchangeConfigs[ExchangeId].values = values;
        _ExchangeConfigs[ExchangeId].version += 1;
        emit SetExchangeConfig(ExchangeId, values, _ExchangeConfigs[ExchangeId].version);
    }

    function _setExchangeAssetConfig(
        uint256 ExchangeId,
        address assetToken,
        uint256[] memory values
    ) internal {
        _ExchangeAssetConfigs[ExchangeId][assetToken].values = values;
        _ExchangeAssetConfigs[ExchangeId][assetToken].version += 1;
        emit SetExchangeAssetConfig(ExchangeId, assetToken, values, _ExchangeAssetConfigs[ExchangeId][assetToken].version);
    }
}