// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../src/proxyFactory/ProxyFactory.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import "./test_setUp.sol";

contract TestProxyFactory is Test, Setup{

    //Note test for createProxy done in gmxAdapter tests while initializing the contracts.

    ProxyFactory private _proxyFactory;
    
    function setUp() public {
        _proxyFactory = new ProxyFactory();
    
        setUpGmxConfig();

        _proxyFactory.initialize(_weth);
        _proxyFactory.upgradeTo(_exchangeId, _implementation);

        //Set Maintainer
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testInitialize() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly initialized");
        assertEq(_proxyFactory.owner(), address(this), "Owner was not correctly initialized");
    }

    function testUpgradeTo() public{
        assertEq(_proxyFactory.getImplementationAddress(_exchangeId), _implementation, "Incorrect implementation was set");

        //Address which is not owner of contract should not be able to call the upgradeTo function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.upgradeTo(_exchangeId, _implementation);
    }

    function testWeth() public{
        assertEq(_proxyFactory.weth(), _weth, "WETH was not correctly returned");
    }

    function testSetMaintainer() public{
        assertEq(_proxyFactory.getMainatinerStatus(_maintainer), true);

        //Address which is not owner of contract should not be able to call the setMaintainer function
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        _proxyFactory.setMaintainer(_maintainer, true);
    }

    function testSetExchangeConfig() public{
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

    function testSetExchangeAssetConfig() public{
        _proxyFactory.setExchangeAssetConfig(_exchangeId, _wbtc, gmxExchangeAssetConfigs);
        assertEq(_proxyFactory.getExchangeAssetConfig(_exchangeId, _wbtc), gmxExchangeAssetConfigs);

        //Maintainer should be able to call the function
        vm.prank(_maintainer);
        _proxyFactory.setExchangeAssetConfig(_exchangeId + 1, _weth, gmxExchangeAssetConfigs);
        assertEq(_proxyFactory.getExchangeAssetConfig(_exchangeId + 1, _weth), gmxExchangeAssetConfigs);

        //Address which is not owner or maintiner of contract should not be able to call the getExchangeAssetConfig function
        vm.expectRevert("OnlyMaintainerOrAbove");
        vm.prank(address(0));
        _proxyFactory.setExchangeAssetConfig(_exchangeId, _wbtc, gmxExchangeAssetConfigs);
    }

    function testGetConfigVersions() public{
        (uint32 exchangeConfigVersion, uint32 assetConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId, _wbtc);
        assertEq(exchangeConfigVersion, 0);
        assertEq(assetConfigVersion, 0);

        (exchangeConfigVersion, assetConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId + 1, _weth);
        assertEq(exchangeConfigVersion, 0);
        assertEq(assetConfigVersion, 0);

        //Updating asset and exchange config once again to check if the version is increasing
        _proxyFactory.setExchangeConfig(_exchangeId, gmxExchangeConfigs);
        _proxyFactory.setExchangeAssetConfig(_exchangeId, _wbtc, gmxExchangeAssetConfigs);

        (exchangeConfigVersion, assetConfigVersion) = _proxyFactory.getConfigVersions(_exchangeId, _wbtc);
        assertEq(exchangeConfigVersion, 1);
        assertEq(assetConfigVersion, 1);
    }

    function testCreateProxy() public{
        vm.prank(_account);
        _proxyFactory.createProxy(1, _dai, _wbtc, false);
    }

    //The following test cases are not possible to write until we have an implementation contract live on mainnet / testnet
    //ToDo - write test for openPosition
    //ToDo - write test for closePosition
    //ToDo - write test for closeOrder
    //ToDo - test the getProxyExchangeId function
    //ToDo - test the getExchangeProxy function
    //ToDo - test the getTradingProxy function
}
