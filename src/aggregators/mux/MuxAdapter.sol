// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IWETH.sol";
import "../../interfaces/IMuxOrderBook.sol";

import "../../components/ImplementationGuard.sol";
import "./Storage.sol";
import "./Config.sol";
import "./Positions.sol";

import "../../../lib/forge-std/src/console.sol";

contract MuxAdapter is Storage, Config, Positions, ImplementationGuard, ReentrancyGuardUpgradeable{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    address internal immutable _WETH;

    constructor(address weth) ImplementationGuard() {
        _WETH = weth;
    }

    receive() external payable {}

    modifier onlyTraderOrFactory() {
        require(msg.sender == _account.account || msg.sender == _factory, "OnlyTraderOrFactory");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory, "onlyFactory");
        _;
    }

    function initialize(
        uint256 exchangeId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(exchangeId == EXCHANGE_ID, "Invalidexchange");

        _factory = msg.sender;

        _account.account = account;
        _account.collateralToken = collateralToken;
        _account.indexToken = assetToken;
        _account.isLong = isLong;
        _account.collateralDecimals = IERC20MetadataUpgradeable(collateralToken).decimals();
        _updateConfigs();
        _subAccountId = encodeSubAccountId(isLong);
    }

    function accountState() external view returns(AccountState memory){
        return _account;
    }

    function encodeSubAccountId(bool isLong) internal view returns (bytes32)
    {
        uint8 collateralId = _collateralConfigs.id;
        uint8 assetId = _assetConfigs.id;
        return bytes32(
            (uint256(uint160(address(this))) << 96) |
            (uint256(collateralId) << 88) |
            (uint256(assetId) << 80) |
            (uint256(isLong ? 1 : 0) << 79)
        );
    }

    //ToDo - how do we implement accountState function?

    /// @notice Place a openning request on MUX.
    function placePositionOrder(
        address collateralToken,
        uint96 collateralAmount, // tokenIn.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 flags, // MARKET, TRIGGER
        uint96 assetPrice, // 1e18
        uint96 collateralPrice, // 1e18
        uint32 deadline,
        bool isLong,
        address profitToken,
        PositionOrderExtra memory extra
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _cleanOrders();

        uint8 profitTokenId = getTokenId(profitToken);
        //We will not be consider the extra.tpslProfitTokenId sent by the user.
        //We will be using profitTokenAddress supplied during the time of proxy creation
        if(!isLong){
            extra.tpslProfitTokenId = profitTokenId;
        }

        PositionContext memory context = PositionContext({
            collateralAmount : collateralAmount,
            size : size,
            price : price,
            flags : flags,
            assetPrice : assetPrice,
            collateralPrice : collateralPrice,
            profitTokenId : profitTokenId,
            subAccountId : _subAccountId,
            deadline : deadline,
            isLong : isLong,
            extra : extra
        });
        if (collateralToken == _WETH) {
            IWETH(_WETH).deposit{ value: collateralAmount }();
        }
        IERC20Upgradeable(_account.collateralToken).approve(_exchangeConfigs.orderBook, context.collateralAmount);

        _placePositionOrder(context);
    }

    function cancelOrder(uint64[] memory orderIds) external onlyTraderOrFactory nonReentrant{
        for (uint256 i = 0; i < orderIds.length; i++) {
            bool success = _cancelOrder(orderIds[i]);
            require(success, "CancelFailed");
        }
    }

    function getPendingOrderKeys() external view returns (bytes32[] memory){
        return _getPendingOrders();
    }


    function _isMarketOrder(uint8 flags) internal pure returns (bool) {
        return (flags & POSITION_MARKET_ORDER) != 0;
    }

    function _cleanOrders() internal {
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            //ToDo - Beware of dataloss from typecasting
            uint64 key = uint64(bytes8(pendingKeys[i]));
            ( ,bool notExist) = LibMux.getOrder(_exchangeConfigs, key);
            if (notExist) {
                _removePendingOrder(key);
            }
        }
    }

}