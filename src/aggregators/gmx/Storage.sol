// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

import "./Types.sol";

contract Storage is Initializable {
    uint256 internal constant EXCHANGE_ID = 1;

    uint32 internal _localexchangeVersion;
    mapping(address => uint32) _localAssetVersions;

    address internal _factory;
    bytes32 internal _gmxPositionKey;

    ExchangeConfigs internal _exchangeConfigs;
    TokenConfigs internal _assetConfigs;

    AccountState internal _account;
    EnumerableSetUpgradeable.Bytes32Set internal _pendingOrders;

    //ToDo - Do we need these gaps?
    //bytes32[50] private __gaps;
}