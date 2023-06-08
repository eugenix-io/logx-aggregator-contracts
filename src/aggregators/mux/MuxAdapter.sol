// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import "../../interfaces/IWETH.sol";
import "../../interfaces/IMuxOrderBook.sol";

import "../../components/ImplementationGuard.sol";
import "./Storage.sol";
import "./Config.sol";

contract MuxAdapter is Storage, Config, ImplementationGuard, ReentrancyGuardUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Address for address;

    address internal immutable _WETH;

    event Withdraw(
        address collateralAddress,
        address account,
        uint256 balance
    );

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
        uint8 collateralId,
        uint8 assetId,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(exchangeId == EXCHANGE_ID, "Invalidexchange");

        _factory = msg.sender;

        _account.account = account;
        _account.collateralToken = collateralToken;
        _account.collateralId = collateralId;
        _account.indexId = assetId;
        _account.isLong = isLong;
        _updateConfigs();
        _subAccountId = encodeSubAccountId(isLong);
    }

    function accountState() external view returns(AccountState memory){
        return _account;
    }

    function getSubAccountId() external view returns(bytes32){
        return _subAccountId;
    }

    function encodeSubAccountId(bool isLong) internal view returns (bytes32)
    {
        return bytes32(
            (uint256(uint160(address(this))) << 96) |
            (uint256(_account.collateralId) << 88) |
            (uint256(_account.indexId) << 80) |
            (uint256(isLong ? 1 : 0) << 72)
        );
    }

    /// @notice Place a openning request on MUX.
    function placePositionOrder(
        uint96 collateralAmount, // tokenIn.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 flags, // MARKET, TRIGGER
        uint96 assetPrice, // 1e18
        uint96 collateralPrice, // 1e18
        uint32 deadline,
        bool isLong,
        uint8 profitTokenId,
        PositionOrderExtra memory extra
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _cleanOrders();

        uint32 positionDeadline;
        uint96 positionPrice;

        //For a market order, if the deadline and price are not zero, transaction will fail on MUX side
        if((flags & POSITION_MARKET_ORDER) != 0){
            positionDeadline = 0;
            positionPrice = 0;
        }else{
            positionDeadline = deadline;
            positionPrice = price;
        }

        //For an open order, if the profitTokenId is not zero, transaction will fail on MUX side
        if((flags & POSITION_OPEN) != 0){
            //We will not have to deposit or give the approvals for close position
            if (_account.collateralToken == _WETH) {
                IWETH(_WETH).deposit{ value: collateralAmount }();
            }
            IERC20Upgradeable(_account.collateralToken).approve(_exchangeConfigs.orderBook, collateralAmount);
        }

        PositionContext memory context = PositionContext({
            collateralAmount : collateralAmount,
            size : size,
            price : positionPrice,
            flags : flags,
            assetPrice : assetPrice,
            collateralPrice : collateralPrice,
            profitTokenId : profitTokenId,
            subAccountId : _subAccountId,
            deadline : positionDeadline,
            isLong : isLong,
            extra : extra
        });

        _placePositionOrder(context);
    }

    function cancelOrders(uint64[] memory orderIds) external onlyTraderOrFactory nonReentrant{
        for (uint256 i = 0; i < orderIds.length; i++) {
            bool success = _cancelOrder(orderIds[i]);
            require(success, "CancelFailed");
        }
    }

    function getPendingOrderKeys() external view returns (uint64[] memory){
        return _getPendingOrders();
    }

    function withdraw() external nonReentrant {
        _updateConfigs();
        _cleanOrders();

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            if (_account.collateralToken == _WETH) {
                IWETH(_WETH).deposit{ value: ethBalance }();
            } else {
                AddressUpgradeable.sendValue(payable(_account.account), ethBalance);
                emit Withdraw(
                    _account.collateralToken,
                    _account.account,
                    ethBalance
                );
            }
        }
        uint256 balance = IERC20Upgradeable(_account.collateralToken).balanceOf(address(this));
        if (balance > 0) {
            _transferToUser(balance);
            emit Withdraw(
            _account.collateralToken,
            _account.account,
            balance
        );
        }
    }

    function _transferToUser(uint256 amount) internal {
        if (_account.collateralToken == _WETH) {
            IWETH(_WETH).withdraw(amount);
            Address.sendValue(payable(_account.account), amount);
        } else {
            IERC20Upgradeable(_account.collateralToken).safeTransfer(_account.account, amount);
        }
    }

    function _isMarketOrder(uint8 flags) internal pure returns (bool) {
        return (flags & POSITION_MARKET_ORDER) != 0;
    }

    function _cleanOrders() internal {
        uint64[] memory pendingKeys = _pendingOrders;
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            uint64 key = pendingKeys[i];
            ( ,bool notExist) = LibMux.getOrder(_exchangeConfigs, key);
            if (notExist) {
                _removePendingOrder(key);
            }
        }
    }

}