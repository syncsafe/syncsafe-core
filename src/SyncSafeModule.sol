// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeProxyFactory} from "@safe/contracts/proxies/SafeProxyFactory.sol";
import {SyncSafeAddress, SafeCreationParams} from "./libraries/SyncSafeAddress.sol";
import {HoldsBalance} from "./utils/HoldsBalance.sol";
import {SafeProxy} from "@safe/contracts/proxies/SafeProxy.sol";
import {OApp} from "@layerzero/oapp/OApp.sol";
import {Origin} from "@layerzero/oapp/interfaces/IOAppReceiver.sol";
import {
  MessagingReceipt,
  MessagingFee
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Safe} from "@safe/contracts/Safe.sol";

import {ITransactionGuard} from "../lib/safe/contracts/base/GuardManager.sol";
import {IModuleGuard} from "../lib/safe/contracts/base/ModuleManager.sol";
import {Enum} from "../lib/safe/contracts/libraries/Enum.sol";
import {ISafe} from "../lib/safe/contracts/interfaces/ISafe.sol";

using SyncSafeAddress for SafeProxyFactory;

// TODO add ITransactionGuard, IModuleGuard
contract SyncSafeModule is OApp, HoldsBalance {
  SafeProxyFactory public immutable factory;
  SyncSafeModule internal immutable _syncModule;
  mapping(SafeProxy proxy => uint32[] chains) internal _chainIds;

  mapping(SafeProxy proxy => SafeCreationParams) public proxyCreationParams;

  constructor(SafeProxyFactory _factory, address _endpoint, address _delegate)
    OApp(_endpoint, _delegate)
    Ownable(_delegate)
  {
    factory = _factory;
    _syncModule = SyncSafeModule(payable(address(this)));
  }

  function getAddress(SafeCreationParams memory params) public view returns (address addr) {
    addr = factory.getAddress(params);
  }

  function getAddressOnChain(SafeCreationParams memory params, uint32 chainId) public view returns (address addr) {
    addr = factory.getAddressOnChain(params, chainId);
  }

  function delegateActivateModule() public {
    Safe(payable(address(this))).enableModule(address(_syncModule));
  }

  function _getSetupData() internal pure returns (bytes memory data) {
    data = abi.encodeWithSelector(this.delegateActivateModule.selector);
  }

  function _getInitializationData(address[] memory _owners, uint256 _threshold)
    internal
    view
    returns (bytes memory initializer)
  {
    bytes memory data = _getSetupData();
    initializer = abi.encodeWithSelector(
      Safe.setup.selector, _owners, _threshold, _syncModule, data, address(0), address(0), 0, address(0)
    );
  }

  function _initDeployProxy(
    address _singleton,
    address[] memory _owners,
    uint256 _threshold,
    uint96 nonce,
    uint32[] memory chains
  ) internal returns (SafeProxy proxy) {
    bytes memory initializer = _getInitializationData(_owners, _threshold);

    proxy = factory.createChainSpecificProxyWithNonce(_singleton, initializer, nonce);

    SafeCreationParams memory params =
      SafeCreationParams({initializerHash: keccak256(initializer), _singleton: address(_syncModule), nonce: nonce});
    proxyCreationParams[proxy] = params;

    _setChains(proxy, chains);
  }

  function _setChains(SafeProxy proxy, uint32[] memory chains) internal {
    _chainIds[proxy] = chains;
  }

  function initDeployProxy(
    address _singleton,
    address[] calldata _owners,
    uint256 _threshold,
    uint96 nonce,
    uint32[] calldata chains
  ) public payable returns (SafeProxy proxy) {
    proxy = _initDeployProxy(_singleton, _owners, _threshold, nonce, chains);
    _defaultFund();
    _broadcastToChains(_singleton, _owners, _threshold, nonce, chains);
  }

  function _defaultFund() internal {
    _fund(msg.sender, msg.value);
  }

  receive() external payable {
    _fund(msg.sender, msg.value);
  }

  function chainIds(SafeProxy proxy) public view returns (uint32[] memory) {
    return _chainIds[proxy];
  }

  function _removeChainFromList(uint32[] memory chains, uint32 chain) internal pure returns (uint32[] memory newChains) {
    newChains = new uint32[](chains.length - 1);
    uint32 j = 0;
    for (uint32 i = 0; i < chains.length; i++) {
      if (chains[i] != chain) {
        newChains[j] = chains[i];
        j++;
      }
    }
    return newChains;
  }

  function _getExecutionOptions(uint128 _gasLimit) internal pure returns (bytes memory options) {
    options = abi.encodePacked(uint256(0x00030100110100000000000000000000000000000000) & _gasLimit);
  }

  function _broadcastToChains(
    address _singleton,
    address[] memory _owners,
    uint256 _threshold,
    uint96 nonce,
    uint32[] memory chains
  ) internal {
    MessagingReceipt memory receipt;
    bytes memory options = _getExecutionOptions(5000000);
    uint256 providedFee = msg.value;
    for (uint32 i = 0; i < chains.length; i++) {
      uint32 chain = chains[i];
      uint32[] memory newChains = _removeChainFromList(chains, chain);
      bytes memory data = abi.encodePacked(_singleton, _owners, _threshold, nonce, newChains);
      address refundAddress = i == chains.length - 1 ? msg.sender : address(this);
      receipt = _lzSend(chain, data, options, MessagingFee({nativeFee: providedFee, lzTokenFee: 0}), refundAddress);
      providedFee -= receipt.fee.nativeFee;
    }
  }

  /**
   *  @dev Batch send requires overriding this function from OAppSender because the msg.value contains multiple fees
   */
  function _payNative(uint256 _nativeFee) internal virtual override returns (uint256 nativeFee) {
    if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
    return _nativeFee;
  }

  function _getPeerOrRevert(uint32) internal view virtual override returns (bytes32) {
    return bytes32(uint256(uint160(address(_syncModule))));
  }

  function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata)
    internal
    virtual
    override
  {
    (address _singleton, address[] memory _owners, uint256 _threshold, uint96 nonce, uint32[] memory chains) =
      abi.decode(_message, (address, address[], uint256, uint96, uint32[]));
    _initDeployProxy(_singleton, _owners, _threshold, nonce, chains);
  }

  /**
   * @dev Quotes the gas needed to pay for the full omnichain transaction.
   * @return fees Estimated gas fee in native gas.
   */
  function quote(address _singleton, address[] memory _owners, uint256 _threshold, uint96 nonce, uint32[] memory chains)
    public
    view
    returns (uint256[] memory fees)
  {
    bytes memory options = _getExecutionOptions(5000000);
    fees = new uint256[](chains.length);

    for (uint32 i = 0; i < chains.length; i++) {
      uint32 chain = chains[i];
      uint32[] memory newChains = _removeChainFromList(chains, chain);
      bytes memory data = abi.encodePacked(_singleton, _owners, _threshold, nonce, newChains);
      fees[i] = _quote(chain, data, options, false).nativeFee;
    }
  }

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
