// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeProxyFactory} from "@safe/contracts/proxies/SafeProxyFactory.sol";
import {SyncSafeAddress, SafeCreationParams} from "./libraries/SyncSafeAddress.sol";
import {HoldsBalance} from "./utils/HoldsBalance.sol";
import {SafeProxy} from "@safe/contracts/proxies/SafeProxy.sol";
import {OApp} from "@layerzero/oapp/OApp.sol";
import {Origin} from "@layerzero/oapp//interfaces/IOAppReceiver.sol";

using SyncSafeAddress for SafeProxyFactory;

contract SyncSafeModule is OApp, HoldsBalance {
  SafeProxyFactory public immutable factory;
  SyncSafeModule internal immutable _syncModule;

  mapping(SafeProxy proxy => SafeCreationParams) public proxyCreationParams;

  constructor(SafeProxyFactory _factory, address _endpoint, address _delegate) OApp(_endpoint, _delegate) {
    factory = _factory;
    _syncModule = SyncSafeModule(payable(address(this)));
  }

  function getAddress(SafeCreationParams memory params) public view returns (address addr) {
    addr = factory.getAddress(params);
  }

  function getAddressOnChain(SafeCreationParams memory params, uint32 chainId) public view returns (address addr) {
    addr = factory.getAddressOnChain(params, chainId);
  }

  function initDeployProxy(address _singleton, bytes memory initializer, uint96 nonce)
    public
    payable
    returns (SafeProxy proxy)
  {
    proxy = factory.createChainSpecificProxyWithNonce(_singleton, initializer, nonce);

    SafeCreationParams memory params =
      SafeCreationParams({initializerHash: keccak256(initializer), _singleton: address(_syncModule), nonce: nonce});
    proxyCreationParams[proxy] = params;
  }

  function _defaultFund(address eoa, uint256 amount) internal {
    _fund(eoa, amount);
  }

  receive() external payable {
    _fund(msg.sender, msg.value);
  }

  function _lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _message,
    address _executor,
    bytes calldata _extraData
  ) internal virtual override {}
}
