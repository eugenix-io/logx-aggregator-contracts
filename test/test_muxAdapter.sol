// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.17;

import "../lib/forge-std/src/Test.sol";

import "../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

import "../src/interfaces/IMuxAggregator.sol";
import "../src/interfaces/IWETH.sol";
import "../lib/forge-std/src/interfaces/IERC20.sol";

import "../src/aggregators/mux/MuxAdapter.sol";
import "./test_muxSetUp.sol";
import "../src/aggregators/mux/Types.sol";

contract TestMuxAdapter is Test, Setup{
    IMuxProxyFactory private _proxyFactory;
    IERC20 private _erc20;
    IWETH private _iweth;

    IMuxAggregator private _muxAdapterProxyLong;
    IMuxAggregator private _muxAdapterProxyShort;
    MuxAdapter private _muxAdapterInstance;

    event OpenPosition(address collateralToken, address indexToken, bool isLong, PositionContext context);
    event ClosePosition(address collateralToken, address indexToken, bool isLong, PositionContext context);
    event Withdraw(
        address collateralAddress,
        address account,
        uint256 balance
    );

    function setUp() public {
        _muxAdapterInstance = new MuxAdapter(_weth);
        setUpMuxConfig();

        //For the sake of this testing, the TestGmxAdapter contract will be acting like proxyFactory. Therefore, we mock all the calls made by GmxAdapter to Proxy factory with address(this)
        //Mock implementation() call for creating Aggregator contract
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.implementation.selector), abi.encode(_muxAdapterInstance));
        //Mock call to factory during _updateConfigs()
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getConfigVersions.selector), abi.encode(1, 1));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeAssetConfig.selector, 2, _wbtc), abi.encode(muxExchangeAssetConfigs_btc));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeAssetConfig.selector, 2, _weth), abi.encode(muxExchangeAssetConfigs_weth));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeAssetConfig.selector, 2, _dai), abi.encode(muxExchangeAssetConfigs_dai));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeAssetConfig.selector, 2, _usdc), abi.encode(muxExchangeAssetConfigs_usdc));
        vm.mockCall(address(this), abi.encodeWithSelector(_proxyFactory.getExchangeConfig.selector), abi.encode(muxExchangeConfigs));
        //Mock transferFrom calls to collateral tokens
        vm.mockCall(address(_wbtc), abi.encodeWithSelector(_erc20.transferFrom.selector), abi.encode());
        vm.mockCall(address(_dai), abi.encodeWithSelector(_erc20.transferFrom.selector), abi.encode());

        // ----------- Long Position Initialization ----------------
        address proxyLong;
        //for long position on GMX, the collateral and asset token are the same.
        bytes32 proxyIdLong = keccak256(abi.encodePacked(_exchangeId, _account, _wbtc, _wbtc, _wbtc, true));
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

        _muxAdapterProxyLong = IMuxAggregator(proxyLong);

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

        _muxAdapterProxyShort = IMuxAggregator(proxyShort);
    }

    function testMuxAdapterInitialization() public{
        AccountState memory currentAccountLong = _muxAdapterProxyLong.accountState();
        assertEq(currentAccountLong.account, _account);
        assertEq(currentAccountLong.collateralToken, _wbtc);
        assertEq(currentAccountLong.indexToken, _wbtc);
        assertEq(currentAccountLong.isLong, true);

        AccountState memory currentAccountShort = _muxAdapterProxyShort.accountState();
        assertEq(currentAccountShort.account, _account);
        assertEq(currentAccountShort.collateralToken, _dai);
        assertEq(currentAccountShort.indexToken, _weth);
        assertEq(currentAccountShort.isLong, false);
    }

    function testMuxAdapterOpenPosition() public{
        PositionOrderExtra memory extra = PositionOrderExtra({
            tpslProfitTokenId : 0,
            tpPrice : 0,
            slPrice : 0,
            tpslDeadline : 0
        });
        uint8 flags = 0x80 + 0x40; //Open Position Order | Market Order
        PositionContext memory openOrderContext;
        vm.expectEmit(true, true, true, false);
        emit OpenPosition(_wbtc, _wbtc, true, openOrderContext);
        //Placing a long open position order with collateral of 0.18 BTC and size $600. price is 0 since it is a Market Order, price of both asset and collateral (BTC) is given as $26451.3 and profitToken is USDC
        _muxAdapterProxyLong.placePositionOrder(_wbtc, 18000000, 600000000000000000000, 0, flags, 26451300000000000000000, 26451300000000000000000, 0, true, _usdc, extra);

        flags = 0x80; //Open Position Order | limit Order
        vm.expectEmit(true, true, true, false);
        emit OpenPosition(_dai, _weth, false, openOrderContext);
        //Placing a short open position order with collateral of 18 DAI and size $600. price is $20451.3 for the Limit Order, price of asset (BTC) is given as $26451.3, collateral price (DAI) at $1 and profitToken is USDC
        _muxAdapterProxyShort.placePositionOrder(_dai, 180000000000000000000, 600000000000000000000, 20451300000000000000000, flags, 26451300000000000000000, 1000000000000000000, uint32(block.timestamp+10), false, _usdc, extra);

        flags = 0x80 + 0x08; //Open Position Order | TPSL Order
        //Take Profit price for BTC at $28451.2 and Stop Loss price for BTC at 24451.2
        extra = PositionOrderExtra({
            tpslProfitTokenId : 4,
            tpPrice : 28451300000000000000000,
            slPrice : 24451300000000000000000,
            tpslDeadline : uint32(block.timestamp+100)
        });
        vm.expectEmit(true, true, true, false);
        emit OpenPosition(_wbtc, _wbtc, true, openOrderContext);
        //Placing a long open position position with collateral of 0.18 BTC and size $600. price is 0 for the TPSL Order, price of both asset and collateral (BTC) is given as $26451.3 and profitToken is USDC
        _muxAdapterProxyLong.placePositionOrder(_wbtc, 18000000, 600000000000000000000, 0, flags, 26451300000000000000000, 26451300000000000000000, uint32(block.timestamp+100), true, _usdc, extra);
    }

    function testMuxAdapterClosePosition() public{
        PositionOrderExtra memory extra = PositionOrderExtra({
            tpslProfitTokenId : 0,
            tpPrice : 0,
            slPrice : 0,
            tpslDeadline : 0
        });
        uint8 flags = 0x40; //Open Position Order | Market Order
        PositionContext memory closeOrderContext;
        vm.expectEmit(true, true, true, false);
        emit ClosePosition(_wbtc, _wbtc, true, closeOrderContext);
        //Placing a long close position order with collateral of 0.18 BTC and size $600. price is 0 since it is a Market Order, price of both asset and collateral (BTC) is given as $26451.3 and profitToken is USDC
        _muxAdapterProxyLong.placePositionOrder(_wbtc, 18000000, 600000000000000000000, 0, flags, 26451300000000000000000, 1000000000000000000, 0, true, _wbtc, extra);

        flags = 0x0; //Open Position Order | limit Order
        vm.expectEmit(true, true, true, false);
        emit ClosePosition(_dai, _weth, false, closeOrderContext);
        //Placing a short close position order with collateral of 18 DAI and size $600. price is $20451.3 for the Limit Order, price of asset (BTC) is given as $26451.3, collateral price (DAI) at $1 and profitToken is USDC
        _muxAdapterProxyShort.placePositionOrder(_dai, 180000000000000000000, 600000000000000000000, 28451300000000000000000, flags, 26451300000000000000000, 26451300000000000000000, uint32(block.timestamp+10), false, _weth, extra);

        //Test Cancel Orders
        uint64[] memory ordersBefore = _muxAdapterProxyLong.getPendingOrderKeys();
        uint256 startOrdersLength = ordersBefore.length;

        assertEq(startOrdersLength > 0, true, "0 starting Orders");
        _muxAdapterProxyLong.cancelOrders(ordersBefore);
        uint64[] memory ordersAfter = _muxAdapterProxyLong.getPendingOrderKeys();
        uint256 endOrdersLength = ordersAfter.length;
        assertEq(endOrdersLength < startOrdersLength, true, "All Orders not cancelled");
        assertEq(endOrdersLength == 0, true, "All Orders not cancelled");
    }

    //ToDo - make the function better.
    function testMuxAdapterWithdraw() public{
        vm.expectEmit(true, true, true, false);
        emit Withdraw(_wbtc, _account, 0);
        _muxAdapterProxyLong.withdraw();
    }

    function testMuxAdapterGetSubAccountId() public{
        bytes32 requiredSubAccountId = 0xb6D3e86660A5613D9797A39E8A779D1A4525c945040401000000000000000000;
        bytes32 muxSubAccountId = _muxAdapterProxyLong.getSubAccountId();
        assertEq(muxSubAccountId, requiredSubAccountId);
    }
}