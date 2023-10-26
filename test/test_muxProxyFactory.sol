// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.17;

import "../lib/forge-std/src/Test.sol";
import "../src/muxProxyFactory/muxProxyFactory.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import "./test_muxSetUp.sol";

contract TestProxyFactory is Test, Setup{

    //Note test for createProxy done in muxAdapter tests while initializing the contracts.

    MuxProxyFactory private _proxyFactory;
    
    function setUp() public {
        _proxyFactory = new MuxProxyFactory();
    
        setUpMuxConfig();

        _proxyFactory.initialize(_weth);
        _proxyFactory.upgradeTo(_exchangeId, _implementation);

        //Set Maintainer
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testMuxInitialize() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly initialized");
        assertEq(_proxyFactory.owner(), address(this), "Owner was not correctly initialized");
    }

    function testMuxUpgradeTo() public{
        assertEq(_proxyFactory.getImplementationAddress(_exchangeId), _implementation, "Incorrect implementation was set");

        //Address which is not owner of contract should not be able to call the upgradeTo function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.upgradeTo(_exchangeId, _implementation);
    }

    function tesMuxWeth() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly returned");
    }

    function testMuxSetMaintainer() public{
        assertEq(_proxyFactory.getMainatinerStatus(_maintainer), true);

        //Address which is not owner of contract should not be able to call the setMaintainer function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testMuxSetExchangeConfig() public{
        _proxyFactory.setExchangeConfig(_exchangeId, muxExchangeConfigs);
        assertEq(_proxyFactory.getExchangeConfig(_exchangeId), muxExchangeConfigs);

        //Maintainer should be able to call the function
        vm.prank(_maintainer);
        _proxyFactory.setExchangeConfig(_exchangeId + 1, muxExchangeConfigs);
        assertEq(_proxyFactory.getExchangeConfig(_exchangeId + 1), muxExchangeConfigs);

        //Address which is not owner or maintiner of contract should not be able to call the setExchangeConfig function
        vm.expectRevert("OnlyMaintainerOrAbove");
        vm.prank(address(0));
        _proxyFactory.setExchangeConfig(_exchangeId, muxExchangeConfigs);
    }

    function testMuxGetConfigVersions() public{
        (uint32 exchangeConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId);
        assertEq(exchangeConfigVersion, 0);

        (exchangeConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId + 1);
        assertEq(exchangeConfigVersion, 0);

        //Updating asset and exchange config once again to check if the version is increasing
        _proxyFactory.setExchangeConfig(_exchangeId, muxExchangeConfigs);

        (exchangeConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId);
        assertEq(exchangeConfigVersion, 1);
    }

    function testSetAggregationFee() public{
        _proxyFactory.setAggregationFee(2, true, address(this));
        uint256 fee = _proxyFactory.getAggregationFee();
        bool openPositionAggregationFeeStatus = _proxyFactory.getOpenAggregationFeeStatus();
        address payable feeCollector = _proxyFactory.getFeeCollectorAddress();

        assertEq(fee, 2);
        assertEq(openPositionAggregationFeeStatus, true);
        assertEq(feeCollector, payable(address(this)));
    }

    //The following test cases are not possible to write until we have an implementation contract live on mainnet / testnet
    //ToDo - write test for openPosition
    //ToDo - write test for closePosition
    //ToDo - write test for cancelOrder
    //ToDo - test the getExchangeProxy function
    //ToDo - test the getTradingProxy function
}
