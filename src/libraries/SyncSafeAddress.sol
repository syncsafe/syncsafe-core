// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {SafeProxyFactory} from "@safe/contracts/proxies/SafeProxyFactory.sol";

struct SafeCreationParams {
  bytes32 initializerHash;
  address _singleton;
  uint96 nonce;
}

/**
 * @title SyncSafeAddress
 * @dev Library for geeting SafeProxy deterministic addresses.
 */
library SyncSafeAddress {
  /**
   * @dev Returns the current chain id.
   */
  function getChainId() private view returns (uint32 id) {
    assembly {
      id := chainid()
    }
  }

  /**
   * @dev Returns the init bytecode for a SafeProxy.
   */
  function getInitBytecodeHash(SafeProxyFactory self, address _singleton) private pure returns (bytes32 bytecodeHash) {
    bytes memory creationCode = self.proxyCreationCode();
    bytecodeHash = keccak256(abi.encodePacked(creationCode, uint256(uint160(_singleton))));
  }

  /**
   * @dev Returns the salt for a SafeProxy.
   */
  function getSalt(SafeCreationParams memory params) private view returns (bytes32 salt) {
    salt = keccak256(abi.encodePacked(params.initializerHash, params.nonce, getChainId()));
  }

  /**
   * @dev Returns the address of a SafeProxy.
   */
  function getAddress(SafeProxyFactory self, SafeCreationParams memory params) internal view returns (address addr) {
    bytes32 salt = getSalt(params);
    bytes32 bytecodeHash = getInitBytecodeHash(self, params._singleton);
    addr = Create2.computeAddress(salt, bytecodeHash, address(self));
  }

  /**
   * @dev Returns the address of a SafeProxy on a different chain.
   */
  function getAddressOnChain(SafeProxyFactory self, SafeCreationParams memory params, uint32 chainId)
    internal
    pure
    returns (address addr)
  {
    bytes32 salt = keccak256(abi.encodePacked(params.initializerHash, params.nonce, chainId));
    bytes32 bytecodeHash = keccak256(abi.encodePacked(self.proxyCreationCode(), uint256(uint160(params._singleton))));
    addr = Create2.computeAddress(salt, bytecodeHash, address(self));
  }
}
