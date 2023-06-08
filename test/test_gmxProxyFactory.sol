// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.17;

import "../lib/forge-std/src/Test.sol";
import "../src/gmxProxyFactory/GmxProxyFactory.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import "./test_gmxSetUp.sol";

contract TestProxyFactory is Test, Setup{

    //Note test for createProxy done in gmxAdapter tests while initializing the contracts.

    GmxProxyFactory private _proxyFactory;
    
    function setUp() public {
        _proxyFactory = new GmxProxyFactory();
    
        setUpGmxConfig();

        _proxyFactory.initialize(_weth);
        _proxyFactory.upgradeTo(_exchangeId, _implementation);

        //Set Maintainer
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testGmxInitialize() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly initialized");
        assertEq(_proxyFactory.owner(), address(this), "Owner was not correctly initialized");
    }

    function testGmxUpgradeTo() public{
        assertEq(_proxyFactory.getImplementationAddress(_exchangeId), _implementation, "Incorrect implementation was set");

        //Address which is not owner of contract should not be able to call the upgradeTo function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.upgradeTo(_exchangeId, _implementation);
    }

    function tesGmxtWeth() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly returned");
    }

    function testGmxSetMaintainer() public{
        assertEq(_proxyFactory.getMainatinerStatus(_maintainer), true);

        //Address which is not owner of contract should not be able to call the setMaintainer function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testGmxSetExchangeConfig() public{
        _proxyFactory.setExchangeConfig(_exchangeId, gmxExchangeConfigs);
        assertEq(_proxyFactory.getExchangeConfig(_exchangeId), gmxExchangeConfigs);

        //Maintainer should be able to call the function
        vm.prank(_maintainer);
        _proxyFactory.setExchangeConfig(_exchangeId + 1, gmxExchangeConfigs);
        assertEq(_proxyFactory.getExchangeConfig(_exchangeId + 1), gmxExchangeConfigs);

        //Address which is not owner or maintiner of contract should not be able to call the setExchangeConfig function
        vm.expectRevert("OnlyMaintainerOrAbove");
        vm.prank(address(0));
        _proxyFactory.setExchangeConfig(_exchangeId, gmxExchangeConfigs);
    }

    function testGmxGetConfigVersions() public{
        uint32 exchangeConfigVersion = _proxyFactory.getConfigVersions(_exchangeId);
        assertEq(exchangeConfigVersion, 0);

        exchangeConfigVersion = _proxyFactory.getConfigVersions(_exchangeId + 1);
        assertEq(exchangeConfigVersion, 0);

        //Updating asset and exchange config once again to check if the version is increasing
        _proxyFactory.setExchangeConfig(_exchangeId, gmxExchangeConfigs);

        (exchangeConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId);
        assertEq(exchangeConfigVersion, 1);
    }

    //The following test cases are not possible to write until we have an implementation contract live on mainnet / testnet
    //ToDo - write test for openPosition
    //ToDo - write test for closePosition
    //ToDo - write test for closeOrder
    //ToDo - test the getProxyExchangeId function
    //ToDo - test the getExchangeProxy function
    //ToDo - test the getTradingProxy function
}
