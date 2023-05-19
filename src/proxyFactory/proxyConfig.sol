// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "./Storage.sol";

contract ProxyConfig is Storage {

    event SetExchangeLiquidityPool(uint256 exchangeId, address liquidityPool);

    function _setExchangeLiquidityPool(uint256 exchangeId, address liquidityPool)internal{
        _exchangeLiquidityPool[exchangeId] = liquidityPool;
        emit SetExchangeLiquidityPool(exchangeId, liquidityPool);
    }

    function _getExchangeLiquidityPool(uint256 exchangeId) internal view returns(address liquidityPool){
        liquidityPool = _exchangeLiquidityPool[exchangeId];
    }
}