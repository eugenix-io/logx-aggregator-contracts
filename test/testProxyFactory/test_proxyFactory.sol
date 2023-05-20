// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.19;

import "../../lib/forge-std/src/Test.sol";
import "../../src/proxyFactory/proxyFactory.sol";

contract TestProxyCFactory is Test{

    ProxyFactory private proxyFactory;
    address testWeth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; //Arb1 Weth
    address testImplementation = 0x0000000000000000000000000000000000000002; // To be updated with an existing implementation
    uint testExchangeId = 1;


    function setUp() public {
        proxyFactory = new ProxyFactory();
        proxyFactory.initialize(testWeth);
        proxyFactory.upgradeTo(testExchangeId, testImplementation);
    }

    //ToDo - make sure that nobody other than the owner can call onlyOwner functions.

    //ToDo - test the setMaintainer function
    //ToDo - test the setExchangeConfig function
    //ToDo - test the setExchangeAssetConfig funciton
    //ToDo - test the getProxyExchangeId function
    //ToDo - test the getExchangeProxy function
    //ToDo - test the getTradingProxy function
    //ToDO - test the getConfigVersions function

    function test_initialize() public{
        assertEq(proxyFactory.weth(), testWeth, "WETH was not correctly initialized");
        assertEq(proxyFactory.owner(), address(this), "Owner was not correctly initialized");
    }

    function test_upgradeTo() public{
        assertEq(proxyFactory.getImplementationAddress(testExchangeId), testImplementation, "Incorrect implementation was set");
    }

    function test_weth() public{
        assertEq(proxyFactory.weth(), testWeth, "WETH was not correctly returned");
    }

    //ToDo - write test for createProxy
    //ToDo - write test for openPosition
    //ToDo - write test for closePosition
    //ToDo - write test for closeOrder
}
