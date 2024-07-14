// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SyncSafeModule, SafeProxyFactory, ISafe} from "../src/SyncSafeModule.sol";

contract SafeDeployer is Script {
  SyncSafeModule public module;
  SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  ISafe singleton = ISafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);
  address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c); // 0x6EDCE65403992e310A62460808c4b910D972f10f testnet endpoint

  address sender = 0x55aFE7FDbB76B478d83e2151B468f7C74442B46C;

  function setUp() public {
    module = SyncSafeModule(payable(0x8991690990Ea0A47B41c67c7Fa82d717387eAcD9)); // modify here
  }

  function run() public {
    address[] memory _owners = new address[](1);
    _owners[0] = sender;

    uint32[] memory eids = new uint32[](1);
    eids[0] = uint32(30110); // arbi
    // eids[1] = uint32(40161);

    vm.broadcast();
    module.initDeployProxy{value: 0.0075 ether}(address(singleton), _owners, 1, 1223424112202342346, eids);
  }
}
