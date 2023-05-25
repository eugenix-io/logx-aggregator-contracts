// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../aggregators/mux/Types.sol";

interface IMuxAggregator {

    function initialize(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        address profitToken,
        bool isLong
    ) external;

    function accountState() external returns(AccountState memory);

    function placePositionOrder(
        address collateralToken,
        uint256 collateralAmount, // tokenIn.decimals
        uint256 size, // 1e18
        uint96 price, // 1e18
        uint8 flags, // MARKET, TRIGGER
        uint96 assetPrice, // 1e18
        uint96 collateralPrice, // 1e18
        uint32 deadline,
        bool isLong,
        IMuxOrderBook.PositionOrderExtra memory extra
    ) external payable;
    
    function cancelOrders(bytes32[] calldata keys) external;

    function cancelTimeoutOrders(bytes32[] calldata keys) external;

    function getPendingOrderKeys() external view returns (bytes32[] memory);
}