// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IMuxAggregator.sol";

interface IMuxProxyFactory {

    struct OpenPositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        address profitToken;
        bool isLong;
        uint256 collateralAmount;
        uint256 size;
        uint96 price;
        uint96 collateralPrice;
        uint96 assetPrice;
        uint8 flags;
        bytes32 referralCode;
    }

    struct ClosePositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd;
        uint256 size;
        uint96 price;
        uint96 collateralPrice;
        uint96 assetPrice;
        uint8 flags;
        bytes32 referralCode;
    }

    event SetReferralCode(bytes32 referralCode);
    event SetMaintainer(address maintainer, bool enable);

    function initialize(address weth_) external;

    function weth() external view returns (address);
    
    function implementation() external view returns(address);

    function getImplementationAddress(uint256 exchangeId) external view returns(address);

    function getProxyExchangeId(address proxy) external view returns(uint256);

    function getTradingProxy(bytes32 proxyId) external view returns(address);

    function getExchangeConfig(uint256 ExchangeId) external view returns (uint256[] memory);

    function getExchangeAssetConfig(uint256 ExchangeId, address assetToken) external view returns (uint256[] memory);

    function getMainatinerStatus(address maintainer) external view returns(bool);

    function getConfigVersions(uint256 ExchangeId) external view returns (uint32 exchangeConfigVersion);

    function upgradeTo(uint256 exchangeId, address newImplementation_) external;

    function setExchangeConfig(uint256 ExchangeId, uint256[] memory values) external;

    function setExchangeAssetConfig(uint256 ExchangeId, address assetToken, uint256[] memory values) external;

    function setMaintainer(address maintainer, bool enable) external;

    function createProxy(uint256 exchangeId, address collateralToken, address assetToken, address profitToken, bool isLong) external returns (address);

    function openPosition(OpenPositionArgs calldata args, PositionOrderExtra memory extra) external payable;

    function closePosition(ClosePositionArgs calldata args, PositionOrderExtra memory extra) external payable;

    function cancelOrders(uint256 exchangeId, address collateralToken, address assetToken, bool isLong, bytes32[] calldata keys) external;

    function getPendingOrderKeys(uint256 exchangeId, address collateralToken, address assetToken, bool isLong) external view returns(uint64[] memory);
}
