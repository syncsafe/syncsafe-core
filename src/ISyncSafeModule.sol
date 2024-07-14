// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SafeProxy} from "@safe/contracts/proxies/SafeProxy.sol";
import {SafeCreationParams} from "./libraries/SyncSafeAddress.sol";

interface ISyncSafeModule {
  struct SyncSafeParams {
    bytes32 initBytecodeHash;
    uint32[] chainIds;
    SafeCreationParams creationParams;
  }

  event SyncSafeCreated(SafeProxy proxyAddress, SyncSafeParams params);

  event EmitNewState(address[] owners, uint256 threshold);
}
