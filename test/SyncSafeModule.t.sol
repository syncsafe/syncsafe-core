// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {SafeProxy} from "../lib/safe/contracts/proxies/SafeProxy.sol";
import {ISafe, Safe} from "../lib/safe/contracts/Safe.sol";
import {SyncSafeModule} from "../src/SyncSafeModule.sol";
import {SafeProxyFactory} from "../lib/safe/contracts/proxies/SafeProxyFactory.sol";

interface ISafeProxyFactory {
  function proxyCreationCode() external returns (bytes memory);

  function createChainSpecificProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);

  function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);
}

contract SyncSafeModuleTest is Test {
  SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  ISafe singleton = ISafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);

  address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);

  SyncSafeModule public _syncModule;

  receive() external payable {}

  function setUp() public {
    // Fork
    string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint256 forkId = vm.createFork(MAINNET_RPC_URL, 20298514);
    vm.selectFork(forkId);
    assertEq(vm.activeFork(), forkId);

    _syncModule = new SyncSafeModule(safeProxyFactory, lzEndpoint, address(1));
  }

  function test_decodeMultiSendExecute() public {
    address[] memory _owners = new address[](1);
    _owners[0] = msg.sender;

    uint32[] memory chains = new uint32[](1);
    // chains[0] = uint32(1);
    chains[0] = uint32(30110);

    _syncModule.initDeployProxy{value: 1 ether}(address(singleton), _owners, 1, 23412341234, chains);
  }
}
