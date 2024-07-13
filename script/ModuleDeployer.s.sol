// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SyncSafeModule, SafeProxyFactory, ISafe} from "../src/SyncSafeModule.sol";

contract ModuleDeployer is Script {
  SyncSafeModule public module;
  SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  // ISafe singleton = ISafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);
  address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);

  address sender = 0x55aFE7FDbB76B478d83e2151B468f7C74442B46C;

  function setUp() public {}

  function run() public {
    bytes memory deploycode = abi.encodePacked(type(SyncSafeModule).creationCode, safeProxyFactory, lzEndpoint, sender);

    console.log(vmSafe.toString(deploycode));

    vm.broadcast();
    module = new SyncSafeModule{salt: 0x0e250538228256d4b12dc895ad58284742a988c92af0a6a8e2933dc3d1348fb9}(
      safeProxyFactory, lzEndpoint, sender
    );
  }
}
