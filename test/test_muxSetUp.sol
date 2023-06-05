// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.17;

contract Setup{
    address _wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; //Arb1 Wbtc
    address _weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; //Arb1 Weth
    address _dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; //Arb1 DAI
    address _usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; //Arb1 USDC

    address _maintainer = 0x07068065bEdb261CfBC172648DBfDE38bC81dfD0;
    address _account = 0x07068065bEdb261CfBC172648DBfDE38bC81dfD0;

    address _implementation = 0x81CE58B23FC61a78C38574F760d8D77530f1EF9D;

    uint256 _exchangeId = 2;

    uint256[] public muxExchangeConfigs = new uint256[](3);

    function setUpMuxConfig() public{
        //GMX Exchange config details
        muxExchangeConfigs[0] = uint256(bytes32(bytes20(0x3e0199792Ce69DC29A0a36146bFa68bd7C8D6633))); //MUX Liquidity Pool
        muxExchangeConfigs[1] = uint256(bytes32(bytes20(0xa19fD5aB6C8DCffa2A295F78a5Bb4aC543AAF5e3))); //MUX Order Book
        muxExchangeConfigs[2] = uint256(bytes32(bytes20(0x0000000000000000000000000000000000000000))); //GMX Referral Code
    }
}