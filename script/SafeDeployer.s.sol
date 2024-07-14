// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SyncSafeModule, SafeProxyFactory, ISafe} from "../src/SyncSafeModule.sol";

contract SafeDeployer is Script {
  SyncSafeModule public module;
  SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  ISafe singleton = ISafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);
  address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);

  address sender = 0x55aFE7FDbB76B478d83e2151B468f7C74442B46C;

  function setUp() public {
    module = SyncSafeModule(payable(0x281973cB6579afc99f6143da827B101281C7c29F)); // modify here
  }

  function run() public {
    address[] memory _owners = new address[](1);
    _owners[0] = sender;

    uint32[] memory chains = new uint32[](1);
    chains[0] = uint32(40161);
    // chains[1] = uint32(40245);

    vm.broadcast();
    module.initDeployProxy{value: 0.01 ether}(address(singleton), _owners, 1, 123812086, chains);
  }
}
