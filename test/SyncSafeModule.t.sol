// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {SafeProxy} from "../lib/safe/contracts/proxies/SafeProxy.sol";
import {ISafe, Safe} from "../lib/safe/contracts/Safe.sol";
import {SyncSafeModule} from "../src/SyncSafeModule.sol";
import {SafeProxyFactory} from "../lib/safe/contracts/proxies/SafeProxyFactory.sol";
import {Enum} from "../lib/safe/contracts/libraries/Enum.sol";

interface ISafeProxyFactory {
  function proxyCreationCode() external returns (bytes memory);

  function createChainSpecificProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);

  function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);
}

contract CreateSyncSafeTest is Test {
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

  function test_syncSafeCreation() public {
    address[] memory _owners = new address[](1);
    _owners[0] = msg.sender;

    uint32[] memory chains = new uint32[](2);
    // chains[0] = uint32(1);
    chains[0] = uint32(30110);
    chains[1] = uint32(30109);

    _syncModule.initDeployProxy{value: 1 ether}(address(singleton), _owners, 1, 23412341234, chains);
  }
}

contract UpdateSyncSafeTest is Test {
  SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
  ISafe singleton = ISafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);

  address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);

  SyncSafeModule public _syncModule;
  Safe proxy;

  receive() external payable {}

  function deploySyncSafe() public returns (SafeProxy _proxy) {
    address[] memory _owners = new address[](1);
    _owners[0] = address(this);

    uint32[] memory chains = new uint32[](2);
    // chains[0] = uint32(1);
    chains[0] = uint32(30110);
    chains[1] = uint32(30109);

    _proxy = _syncModule.initDeployProxy{value: 1 ether}(address(singleton), _owners, 1, 23412341234, chains);
  }

  function setUp() public {
    // Fork
    string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint256 forkId = vm.createFork(MAINNET_RPC_URL, 20298514);
    vm.selectFork(forkId);
    assertEq(vm.activeFork(), forkId);

    _syncModule = new SyncSafeModule(safeProxyFactory, lzEndpoint, address(1));

    proxy = Safe(payable(deploySyncSafe()));
    vm.label(address(proxy), "proxySafe");
    vm.deal(address(_syncModule), 1 ether);
  }

  // Tests where
  function test_syncSafeAddOwner() public {
    VmSafe.Wallet memory _newOwner = vm.createWallet(string("_newOwner"));

    bytes memory _data = abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", _newOwner.addr, 2);

    proxy.execTransaction(
      address(proxy),
      0, // value
      _data,
      Enum.Operation.Call,
      0,
      0,
      0,
      address(0),
      payable(0),
      abi.encodePacked(uint256(uint160(address(this))), uint8(0), uint256(1))
    );

    address[] memory newOwners = proxy.getOwners();
    assertEq(newOwners.length, 2);
    assertEq(newOwners[1], address(this));
    assertEq(newOwners[0], _newOwner.addr);
  }

  // function test_syncSafeRemoveOwner() public {}
  // function test_syncSafeUpdateThreshold() public {}

  // function test_syncSafeReceiveAddOwner() public {}
  // function test_syncSafeReceiveRemoveOwner() public {}
  // function test_syncSafeReceiveUpdateThreshold() public {}
}
