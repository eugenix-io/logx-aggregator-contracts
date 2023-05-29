// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.17;

import "../lib/forge-std/src/Test.sol";

import "../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

import "../src/interfaces/IGmxAggregator.sol";
import "../src/interfaces/IGmxProxyFactory.sol";
import "../src/interfaces/IGmxRouter.sol";
import "../src/interfaces/IGmxOrderBook.sol";
import "../src/interfaces/IGmxPositionRouter.sol";
import "../src/interfaces/IGmxVault.sol";

import "../src/aggregators/gmx/GmxAdapter.sol";
import "../src/aggregators/gmx/Types.sol";
import "./test_gmxSetUp.sol";

contract TestGmxAdapter is Test, Setup{
    IGmxProxyFactory private _proxyFactory;
    IGmxRouter private _gmxRouter;
    IGmxOrderBook private _gmxOrderBook;
    IGmxPositionRouter private _gmxPositionRouter;
    IGmxVault private _gmxVault;
    IERC20 private _erc20;
    IWETH private _iweth;

    //Initializing two adapters, one for a long position and another for a short position
    IGmxAggregator private _gmxAdapterProxyLong;
    IGmxAggregator private _gmxAdapterProxyShort;
    GMXAdapter private _gmxAdapterInstance;

    event OpenPosition(address collateralToken, address indexToken, bool isLong, OpenPositionContext context);
    event ClosePosition(address collateralToken, address indexToken, bool isLong, ClosePositionContext context);
    event AddPendingOrder(
        LibGmx.OrderCategory category,
        LibGmx.OrderReceiver receiver,
        uint256 index,
        uint256 timestamp
    );

    function setUp() public {
        _gmxAdapterInstance = new GMXAdapter(_weth);
        setUpGmxConfig();

        //For the sake of this testing, the TestGmxAdapter contract will be acting like proxyFactory. Therefore, we mock all the calls made by GmxAdapter to Proxy factory with address(this)
        //Mock implementation() call for creating Aggregator contract
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.implementation.selector), abi.encode(_gmxAdapterInstance));
        //Mock call to factory during _updateConfigs()
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getConfigVersions.selector), abi.encode(1, 1));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeAssetConfig.selector), abi.encode(gmxExchangeAssetConfigs));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeConfig.selector), abi.encode(gmxExchangeConfigs));
        //Mock transferFrom calls to collateral tokens
        vm.mockCall(address(_wbtc), abi.encodeWithSelector(_erc20.transferFrom.selector), abi.encode());
        vm.mockCall(address(_dai), abi.encodeWithSelector(_erc20.transferFrom.selector), abi.encode());
        vm.mockCall(address(_dai), abi.encodeWithSelector(_erc20.transfer.selector), abi.encode());
        vm.mockCall(address(_weth), abi.encodeWithSelector(_erc20.transfer.selector), abi.encode());
        //Mock GMX Vault Swap
        vm.mockCall(address(bytes20(bytes32(gmxExchangeConfigs[0]))), abi.encodeWithSelector(_gmxVault.swap.selector), abi.encode(18000000));
        vm.mockCall(address(_weth), abi.encodeWithSelector(_iweth.deposit.selector), abi.encode());

        // ----------- Long Position Initialization ----------------
        address proxyLong;
        //for long position on GMX, the collateral and asset token are the same.
        bytes32 proxyIdLong = keccak256(abi.encodePacked(_exchangeId, _account, _wbtc, _wbtc, true));
        bytes memory initDataLong = abi.encodeWithSignature(
            "initialize(uint256,address,address,address,bool)",
            _exchangeId,
            _account,
            _wbtc,
            _wbtc,
            true
        );
        bytes memory bytecodeLong = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(this), initDataLong));
        assembly {
            proxyLong := create2(0x0, add(0x20, bytecodeLong), mload(bytecodeLong), proxyIdLong)
        }
        require(proxyLong != address(0), "CreateFailed");

        _gmxAdapterProxyLong = IGmxAggregator(proxyLong);

        // ----------- Short Position Initialization ----------------
        address proxyShort;
        //for short position on GMX, the collateral token is always a stable coin.
        bytes32 proxyIdShort = keccak256(abi.encodePacked(_exchangeId, _account, _dai, _weth, false));
        bytes memory initDataShort = abi.encodeWithSignature(
            "initialize(uint256,address,address,address,bool)",
            _exchangeId,
            _account,
            _dai,
            _weth,
            false
        );
        bytes memory bytecodeShort = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(this), initDataShort));
        assembly {
            proxyShort := create2(0x0, add(0x20, bytecodeShort), mload(bytecodeShort), proxyIdShort)
        }
        require(proxyShort != address(0), "CreateFailed");

        _gmxAdapterProxyShort = IGmxAggregator(proxyShort);
    }

    function testGmxAdapterInitialization() public{
        AccountState memory currentAccountLong = _gmxAdapterProxyLong.accountState();
        assertEq(currentAccountLong.account, _account);
        assertEq(currentAccountLong.collateralToken, _wbtc);
        assertEq(currentAccountLong.indexToken, _wbtc);
        assertEq(currentAccountLong.account, _account);
        assertEq(currentAccountLong.isLong, true);
        assertEq(currentAccountLong.collateralDecimals, 8);

        AccountState memory currentAccountShort = _gmxAdapterProxyShort.accountState();
        assertEq(currentAccountShort.account, _account);
        assertEq(currentAccountShort.collateralToken, _dai);
        assertEq(currentAccountShort.indexToken, _weth);
        assertEq(currentAccountShort.account, _account);
        assertEq(currentAccountShort.isLong, false);
        assertEq(currentAccountShort.collateralDecimals, 18);
    }

    function testGmxAdapterOpenPosition() public{
        OpenPositionContext memory openOrderLongContext;
        vm.expectEmit(true, true, true, false);
        emit OpenPosition(_wbtc, _wbtc, true, openOrderLongContext);
        _gmxAdapterProxyLong.openPosition{value:180000000000000}(_dai, 18000000000000000000, 0, 12038357806412945305, 0, 64, 0, 0);

        OpenPositionContext memory openOrderShortContext;
        vm.expectEmit(true, true, true, false);
        emit OpenPosition(_dai, _weth, false, openOrderShortContext);
        _gmxAdapterProxyShort.openPosition{value:180000000000000}(_dai, 18000000000000000000, 0, 12038357806412945305, 1900000000000000000000, 0, 0, 0);
    }

    function testGmxAdapterClosePosition() public {
        ClosePositionContext memory closeOrderLongContext;
        vm.expectEmit(true, true, true, false);
        emit ClosePosition(_wbtc, _wbtc, true, closeOrderLongContext);
        _gmxAdapterProxyLong.closePosition{value:180000000000000}(18000000000000000000, 12038357806412945305, 1700000000000000000000, 0, 0, 0);

        ClosePositionContext memory closeOrderShortContext;
        vm.expectEmit(true, true, true, false);
        emit ClosePosition(_dai, _weth, false, closeOrderShortContext);
        _gmxAdapterProxyShort.closePosition{value:180000000000000}(18000000000000000000, 12038357806412945305, 0, 64, 0, 0);

        //Test Update Orders
        bytes32[] memory ordersBefore = _gmxAdapterProxyLong.getPendingOrderKeys();
        uint256 startOrdersLength = ordersBefore.length;
        bytes32 orderKey = ordersBefore[0];
        assertEq(startOrdersLength > 0, true, "0 starting Orders");
        _gmxAdapterProxyLong.updateOrder(orderKey, 0, 0, 10000000000000000000, false);

        //Test Cancel Orders
        _gmxAdapterProxyLong.cancelOrders(ordersBefore);
        bytes32[] memory ordersAfter = _gmxAdapterProxyLong.getPendingOrderKeys();
        uint256 endOrdersLength = ordersAfter.length;
        assertEq(endOrdersLength == 0, true, "All Orders not cancelled");
    }
    
    //ToDo - test withdraw
    //ToDo - test cancelTimeout Orders
}