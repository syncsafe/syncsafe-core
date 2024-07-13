// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ITransactionGuard} from "../lib/safe/contracts/base/GuardManager.sol";
import {IModuleGuard} from "../lib/safe/contracts/base/ModuleManager.sol";
import {Enum} from "../lib/safe/contracts/libraries/Enum.sol";
import {ISafe} from "../lib/safe/contracts/interfaces/ISafe.sol";

contract SyncSafeModule is ITransactionGuard, IModuleGuard {
  mapping(address => address[]) prevOwners;
  mapping(address => uint256) prevThreshold;

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
    _saveState();
  }

  function checkAfterExecution(bytes32 hash, bool success) external {
    _checkStateChange(hash, success);
  }

  function checkModuleTransaction(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation,
    address module
  ) external returns (bytes32 moduleTxHash) {
    _saveState();
  }

  function checkAfterModuleExecution(bytes32 txHash, bool success) external {
    _checkStateChange(txHash, success);
  }

  function _saveState() internal {
    prevOwners[msg.sender] = ISafe(msg.sender).getOwners();
    prevThreshold[msg.sender] = ISafe(msg.sender).getThreshold();
  }

  function _checkStateChange(bytes32 hash, bool success) internal {
    // check if signers are still the same
    if (
      keccak256(abi.encodePacked(ISafe(msg.sender).getOwners())) != keccak256(abi.encodePacked(prevOwners[msg.sender]))
    ) {
      // owners changed
      // TODO call layer zero
    }
    if (prevThreshold[msg.sender] != ISafe(msg.sender).getThreshold()) {
      // threshold changed
      // TODO call layer zero
    }
    delete prevOwners[msg.sender];
    delete prevThreshold[msg.sender];
  }
}
