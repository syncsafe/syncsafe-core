// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {SafeProxy} from "../lib/safe/contracts/proxies/SafeProxy.sol";
import {ISafe, Safe} from "../lib/safe/contracts/Safe.sol";
import {SyncSafeModule} from "../src/SyncSafeModule.sol";
import {SafeProxyFactory} from "../lib/safe/contracts/proxies/SafeProxyFactory.sol";

import {Origin} from "@layerzero/oapp/interfaces/IOAppReceiver.sol";

interface ISafeProxyFactory {
  function proxyCreationCode() external returns (bytes memory);

  function createChainSpecificProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);

  function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
    external
    returns (SafeProxy proxy);
}

contract CreationStatePropagationTest is Test {
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

  function test_Creation() public {
    address[] memory _owners = new address[](1);
    _owners[0] = msg.sender;
    uint32[] memory chains = new uint32[](2);
    // chains[0] = uint32(1);
    chains[0] = uint32(30101);
    chains[1] = uint32(30102);

    Origin memory origin =
      Origin({srcEid: uint32(30102), sender: bytes32(uint256(uint160(address(_syncModule)))), nonce: uint64(5999)});
    bytes32 _guid = bytes32(0x1082fdce640a720b13b35c6b9b33fe05a93ef911cc8771d490511c3022b596a2);

    bytes memory data = abi.encode(address(singleton), _owners, uint256(1), uint96(1), chains);

    address _executor = address(0x0);
    bytes memory _extradata = "";

    (address singleton2, address[] memory owners2, uint256 threshold2, uint96 nonce2, uint32[] memory chains2) =
      abi.decode(data, (address, address[], uint256, uint96, uint32[]));

    vm.startPrank(lzEndpoint);
    _syncModule.lzReceive(origin, _guid, data, _executor, _extradata);
    vm.stopPrank();
  }
}

contract StateUpdatePropagationTest is Test {
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

  function test_OwnershipStateUpdate() public {
    address[] memory _owners = new address[](2);
    VmSafe.Wallet memory _newOwner = vm.createWallet(string("_newOwner"));
    _owners[0] = _newOwner.addr;
    _owners[1] = address(this);

    Origin memory origin =
      Origin({srcEid: uint32(30102), sender: bytes32(uint256(uint160(address(_syncModule)))), nonce: uint64(5999)});
    bytes32 _guid = bytes32(0x1082fdce640a720b13b35c6b9b33fe05a93ef911cc8771d490511c3022b596a2);

    bytes memory data = abi.encode(address(proxy), _owners, uint256(1), uint96(0), new bytes32[](0));

    address _executor = address(0x0);
    bytes memory _extradata = "";

    vm.startPrank(lzEndpoint);
    _syncModule.lzReceive(origin, _guid, data, _executor, _extradata);
    vm.stopPrank();

    address[] memory owners = proxy.getOwners();
    assertEq(owners[0], _newOwner.addr);
    assertEq(owners[1], address(this));
  }

  function test_ThresholdStateUpdate() public {
    address[] memory _owners = new address[](2);
    VmSafe.Wallet memory _newOwner = vm.createWallet(string("_newOwner"));
    _owners[0] = _newOwner.addr;
    _owners[1] = address(this);

    Origin memory origin =
      Origin({srcEid: uint32(30102), sender: bytes32(uint256(uint160(address(_syncModule)))), nonce: uint64(5999)});
    bytes32 _guid = bytes32(0x1082fdce640a720b13b35c6b9b33fe05a93ef911cc8771d490511c3022b596a2);

    bytes memory data = abi.encode(address(proxy), _owners, uint256(1), uint96(0), new bytes32[](0));

    address _executor = address(0x0);
    bytes memory _extradata = "";

    vm.startPrank(lzEndpoint);
    _syncModule.lzReceive(origin, _guid, data, _executor, _extradata);

    data = abi.encode(address(proxy), _owners, uint256(2), uint96(0), new bytes32[](0));

    _syncModule.lzReceive(origin, _guid, data, _executor, _extradata);

    vm.stopPrank();

    address[] memory owners = proxy.getOwners();
    assertEq(owners[0], _newOwner.addr);
    assertEq(owners[1], address(this));

    uint256 threshold = proxy.getThreshold();
    assertEq(threshold, 2);
  }
}
