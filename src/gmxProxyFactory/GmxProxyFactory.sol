// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

import "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IGmxAggregator.sol";

import "./GmxStorage.sol";
import "./GmxProxyBeacon.sol";
import "./GmxProxyConfig.sol";

contract GmxProxyFactory is GmxStorage, GmxProxyBeacon, GmxProxyConfig, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct OpenPositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    struct ClosePositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    event SetReferralCode(bytes32 referralCode);
    event SetMaintainer(address maintainer, bool enable);

    function initialize(address weth_) external initializer {
        __Ownable_init();
        _weth = weth_;
    }

    function weth() external view returns (address) {
        return _weth;
    }

    // ======================== getter methods ========================

    //ToDo - make this function only owner or only maintainer
    function getImplementationAddress(uint256 exchangeId) external view returns(address){
        return _implementations[exchangeId];
    }

    function getProxyExchangeId(address proxy) external view returns(uint256){
        return _proxyExchangeIds[proxy];
    }

    function getTradingProxy(bytes32 proxyId) external view returns(address){
        return _tradingProxies[proxyId];
    }

    function getExchangeConfig(uint256 ExchangeId) external view returns (uint256[] memory) {
        return _exchangeConfigs[ExchangeId].values;
    }

    function getExchangeAssetConfig(uint256 ExchangeId, address assetToken) external view returns (uint256[] memory) {
        return _exchangeAssetConfigs[ExchangeId][assetToken].values;
    }

    function getMainatinerStatus(address maintainer) external view returns(bool){
        return _maintainers[maintainer];
    }

    function getConfigVersions(uint256 ExchangeId, address assetToken)
        external
        view
        returns (uint32 ExchangeConfigVersion, uint32 assetConfigVersion)
    {
        return _getLatestVersions(ExchangeId, assetToken);
    }

    // ======================== methods for contract management ========================
    function upgradeTo(uint256 exchangeId, address newImplementation_) external onlyOwner {
        _upgradeTo(exchangeId, newImplementation_);
    }

    function setExchangeConfig(uint256 ExchangeId, uint256[] memory values) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        _setExchangeConfig(ExchangeId, values);
    }

    function setExchangeAssetConfig(
        uint256 ExchangeId,
        address assetToken,
        uint256[] memory values
    ) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        _setExchangeAssetConfig(ExchangeId, assetToken, values);
    }

    function setMaintainer(address maintainer, bool enable) external onlyOwner {
        _maintainers[maintainer] = enable;
        emit SetMaintainer(maintainer, enable);
    }

    // ======================== methods called by user ========================
    function createProxy(
        uint256 exchangeId,
        address collateralToken,
        address assetToken,
        bool isLong
    ) public returns (address) {
        //ToDo - verify collateral and asset IDs before we create a proxy
        return
            _createBeaconProxy(
                exchangeId,
                msg.sender,
                assetToken,
                collateralToken,
                isLong
            );
    }

    function openPosition(OpenPositionArgs calldata args) external payable {
        bytes32 proxyId = _makeProxyId(args.exchangeId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        address proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = createProxy(args.exchangeId, args.collateralToken, args.assetToken, args.isLong);
        }
        if (args.tokenIn != _weth) {
            IERC20Upgradeable(args.tokenIn).safeTransferFrom(msg.sender, proxy, args.amountIn);
        } else {
            require(msg.value >= args.amountIn, "InsufficientAmountIn");
        }

        IGmxAggregator(proxy).openPosition{ value: msg.value }(
            args.tokenIn,
            args.amountIn,
            args.minOut,
            args.sizeUsd,
            args.priceUsd,
            args.flags
        );
    }

    function closePosition(ClosePositionArgs calldata args) external payable {
        address proxy = _mustGetProxy(args.exchangeId, msg.sender, args.collateralToken, args.assetToken, args.isLong);

        IGmxAggregator(proxy).closePosition{ value: msg.value }(
            args.collateralUsd,
            args.sizeUsd,
            args.priceUsd,
            args.flags
        );
    }

    function cancelOrders(
        uint256 exchangeId,
        address collateralToken,
        address assetToken,
        bool isLong,
        bytes32[] calldata keys
    ) external {
        IGmxAggregator(_mustGetProxy(exchangeId, msg.sender, collateralToken, assetToken, isLong)).cancelOrders(keys);
    }

    // ======================== Utility methods ========================
    function _mustGetProxy(
        uint256 exchangeId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal view returns (address proxy) {
        bytes32 proxyId = _makeProxyId(exchangeId, account, collateralToken, assetToken, isLong);
        proxy = _tradingProxies[proxyId];
        require(proxy != address(0), "ProxyNotExist");
    }
}