// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ITransactionGuard} from "../lib/safe/contracts/base/GuardManager.sol";
import {Enum} from "../lib/safe/contracts/libraries/Enum.sol";
import {ISafe} from "../lib/safe/contracts/interfaces/ISafe.sol";

contract SyncSafeModule {
  bytes4[4] internal guardedMethodSignatures = [
    bytes4(0x0d582f13), // addOwnerWithThreshold(address owner, uint256 _threshold)
    bytes4(0xf8dc5dd9), // removeOwner(address prevOwner, address owner, uint256 _threshold)
    bytes4(0xe318b52b), // swapOwner(address prevOwner, address oldOwner, address newOwner)
    bytes4(0x694e80c3) // changeThreshold(uint256 _threshold)
  ];

  bytes4 internal multiSendSelector = 0x8d80ff0a;

  mapping(address => address[]) prevOwners;

  function checkTransaction(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver,
    bytes memory signatures,
    address msgSender
  ) external {
    prevOwners[msg.sender] = ISafe(msg.sender).getOwners();
  }

  function checkAfterExecution(bytes32 hash, bool success) external {
    // check that signers are still the same
    if (
      keccak256(abi.encodePacked(ISafe(msg.sender).getOwners())) != keccak256(abi.encodePacked(prevOwners[msg.sender]))
    ) {
      // owners changed
      // TODO call layer zero...
    }
    delete prevOwners[msg.sender];
  }
}
