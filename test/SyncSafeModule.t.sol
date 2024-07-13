// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface ISafeProxyFactory {
  function deployProxy(address _singleton, bytes memory initializer, bytes32 salt) internal returns (SafeProxy proxy);
}

contract SyncSafeModuleTest is Test {
  ISafeProxyFactory safeProxyFactory = ISafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  address singleton = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;

  function setUp() public {}

  function test_decodeMultiSendExecute() public pure returns (bytes memory) {
    bytes memory initializer;
    safeProxyFactory.deployProxy(singleton, initializer, 0);
  }
}
