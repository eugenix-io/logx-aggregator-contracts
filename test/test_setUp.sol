// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.19;

contract Setup{
    address _wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; //Arb1 Wbtc
    address _weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; //Arb1 Weth
    address _dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; //Arb1 DAI

    address _implementation = 0x81CE58B23FC61a78C38574F760d8D77530f1EF9D; // GMX Adapter implementation on Arb1
    address _maintainer = 0x07068065bEdb261CfBC172648DBfDE38bC81dfD0;
    address _account = 0x07068065bEdb261CfBC172648DBfDE38bC81dfD0;

    uint256 _exchangeId = 1;

    uint256[] public gmxExchangeConfigs = new uint256[](7);
    uint256[] public gmxExchangeAssetConfigs = new uint256[](5);

    function setUpGmxConfig() public{
        //GMX Exchange config details
        gmxExchangeConfigs[0] = uint256(bytes32(bytes20(0x489ee077994B6658eAfA855C308275EAd8097C4A))); //GMX Vault address
        gmxExchangeConfigs[1] = uint256(bytes32(bytes20(0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868))); //GMX Position Router address
        gmxExchangeConfigs[2] = uint256(bytes32(bytes20(0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB))); //GMX Order Book address
        gmxExchangeConfigs[3] = uint256(bytes32(bytes20(0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064))); //GMX Router address
        gmxExchangeConfigs[4] = uint256(bytes32(bytes20(0x0000000000000000000000000000000000000000))); //GMX Referral Code
        gmxExchangeConfigs[5] = 120; //GMX Referral Code
        gmxExchangeConfigs[6] = 172800; //GMX Referral Code

        //GMX Asset config details (dummy values)
        gmxExchangeAssetConfigs.push(0); // reference Oracle
        gmxExchangeAssetConfigs.push(600); // reference Deviation
        gmxExchangeAssetConfigs.push(500); // initial margin rate
        gmxExchangeAssetConfigs.push(0); // maintainence margin rate
        gmxExchangeAssetConfigs.push(3000); // liquidation fee rate
    }
}