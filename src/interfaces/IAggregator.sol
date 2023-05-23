// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../aggregators/gmx/Types.sol";

interface IAggregator {
    function initialize(
        uint256 projectId,
        address account,
        address assetToken,
        address collateralToken,
        uint8 collateralId,
        bool isLong
    ) external;

    function accountState() external returns(AccountState memory);

    function openPosition(
        address tokenIn, //
        uint256 amountIn, // tokenIn.decimals
        uint256 minOut, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable;

    function closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable;

    function liquidatePosition(uint256 liquidatePrice) external payable;

    function cancelOrders(bytes32[] calldata keys) external;

    function cancelTimeoutOrders(bytes32[] calldata keys) external;

    function getPendingOrderKeys() external view returns (bytes32[] memory);
}