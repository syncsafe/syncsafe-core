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
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ISyncSafeModule} from "./ISyncSafeModule.sol";

using SyncSafeAddress for SafeProxyFactory;
using OptionsBuilder for bytes;

// TODO add ITransactionGuard, IModuleGuard
contract SyncSafeModule is OApp, HoldsBalance, ISyncSafeModule {
  SafeProxyFactory public immutable factory;
  SyncSafeModule internal immutable _syncModule;
  mapping(SafeProxy proxy => uint32[] eids) internal _eids;

  mapping(SafeProxy proxy => SafeCreationParams) public proxyCreationParams;

  constructor(SafeProxyFactory _factory, address _endpoint, address _delegate)
    OApp(_endpoint, _delegate)
    Ownable(_delegate)
  {
    factory = _factory;
    _syncModule = SyncSafeModule(payable(address(this)));
  }

  function getAddress(SafeCreationParams memory params) public view returns (address addr) {
    addr = factory.getAddress(params, endpoint.eid());
  }

  function getAddressOnEid(SafeCreationParams memory params, uint32 eid) public view returns (address addr) {
    addr = factory.getAddressOnEid(params, eid);
  }

  function delegateActivateModule() public {
    Safe(payable(address(this))).enableModule(address(_syncModule));
    Safe(payable(address(this))).setGuard(address(_syncModule));
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
    uint32[] memory eids
  ) internal returns (SafeProxy proxy, bytes32 initializerHash) {
    bytes memory initializer = _getInitializationData(_owners, _threshold);

    proxy =
      factory.createProxyWithNonce(_singleton, initializer, uint256(keccak256(abi.encodePacked(nonce, endpoint.eid()))));

    SafeCreationParams memory params =
      SafeCreationParams({initializerHash: keccak256(initializer), _singleton: address(_syncModule), nonce: nonce});
    proxyCreationParams[proxy] = params;

    initializerHash = params.initializerHash;

    _setEids(proxy, eids);

    emit SyncSafeCreated(
      proxy,
      SyncSafeParams({
        initBytecodeHash: factory.getInitBytecodeHash(_singleton),
        eids: eids,
        creationParams: SafeCreationParams({initializerHash: initializerHash, _singleton: _singleton, nonce: nonce})
      })
    );
  }

  function updateOwnersBatch(address[] memory newOwners, uint256 threshold) external {
    address[] memory currentOwners = Safe(payable(this)).getOwners();

    bool hasUpdate;

    for (uint256 i = 0; i < newOwners.length; i++) {
      for (uint256 j = 0; j < currentOwners.length; j++) {
        if (newOwners[i] == currentOwners[j]) break;
        if (j == currentOwners.length - 1) {
          hasUpdate = true;
          Safe(payable(this)).addOwnerWithThreshold(newOwners[i], threshold);
        }
      }
    }

    currentOwners = Safe(payable(this)).getOwners();

    uint256 nRemoved;
    for (uint256 j = 0; j < currentOwners.length; j++) {
      for (uint256 i = 0; i < newOwners.length; i++) {
        if (newOwners[i] == currentOwners[j]) {
          nRemoved = 0;
          break;
        }

        if (i == currentOwners.length - 1) {
          hasUpdate = true;
          address prevOwner = j - nRemoved == 0 ? address(0x1) : currentOwners[j - nRemoved - 1];
          Safe(payable(this)).removeOwner(prevOwner, newOwners[i], threshold);
          nRemoved++;
        }
      }
    }

    if (hasUpdate == false) {
      Safe(payable(this)).changeThreshold(threshold);
    }
  }

  function _updateStateSetup(SafeProxy safeProxy, address[] memory newOwners, uint256 threshold) internal {
    bytes memory data = abi.encodeWithSelector(this.updateOwnersBatch.selector, newOwners, threshold);

    // TODO check Safe conversion
    Safe(payable(safeProxy)).execTransactionFromModule(address(this), 0, data, Enum.Operation.DelegateCall);
  }

  function _setEids(SafeProxy proxy, uint32[] memory eids) internal {
    _eids[proxy] = eids;
  }

  function initDeployProxy(
    address _singleton,
    address[] calldata _owners,
    uint256 _threshold,
    uint96 nonce,
    uint32[] calldata eids
  ) public payable returns (SafeProxy proxy) {
    bytes32 initializerHash;

    (proxy, initializerHash) = _initDeployProxy(_singleton, _owners, _threshold, nonce, eids);
    _defaultFund();

    _broadcastCreationToEids(_singleton, _owners, _threshold, nonce, eids);
  }

  function _defaultFund() internal {
    _fund(msg.sender, msg.value);
  }

  receive() external payable {
    _fund(msg.sender, msg.value);
  }

  function eids(SafeProxy proxy) public view returns (uint32[] memory) {
    return _eids[proxy];
  }

  function _removeEidFromList(uint32[] memory eids, uint32 eid) internal pure returns (uint32[] memory newEids) {
    newEids = new uint32[](eids.length - 1);
    uint32 j = 0;
    for (uint32 i = 0; i < eids.length; i++) {
      if (eids[i] != eid) {
        newEids[j] = eids[i];
        j++;
      }
    }
    return newEids;
  }

  function _createLzData(
    bool isCreate,
    address _singletonOrSafeProxy, // empty if update
    address[] memory _owners,
    uint256 _threshold,
    uint96 nonce, // empty if update
    uint32[] memory newEids // empty if update
  ) internal pure returns (bytes memory data) {
    data = abi.encode(isCreate, _singletonOrSafeProxy, _owners, _threshold, nonce, newEids);
  }

  // broadcast safesync creation
  function _broadcastCreationToEids(
    address _singleton,
    address[] memory _owners,
    uint256 _threshold,
    uint96 nonce,
    uint32[] memory eids
  ) internal {
    uint256 providedFee = msg.value;

    bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(500_000, 0);

    for (uint32 i = 0; i < eids.length; i++) {
      uint32 eid = eids[i];
      uint32[] memory newEids = _removeEidFromList(eids, eid);
      bytes memory data = _createLzData(true, _singleton, _owners, _threshold, nonce, newEids);
      address refundAddress = i == eids.length - 1 ? msg.sender : address(this);
      uint256 nativeFee = _broadcastToEids(eid, data, options, refundAddress, providedFee);
      providedFee -= nativeFee;
    }
  }

  // broadcast safesync update
  function _broadcastNewStateToEids(address[] memory _owners, uint256 _threshold) internal {
    // TODO add a way to use user's safe funds to sponsor the transaction
    uint256 providedFee = address(this).balance;

    uint32[] memory eids = _eids[SafeProxy(payable(msg.sender))];

    bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(150_000, 0);

    for (uint32 i = 0; i < eids.length; i++) {
      uint32 eid = eids[i];
      address _eidSafeProxy = getAddressOnEid(proxyCreationParams[SafeProxy(payable(msg.sender))], eid);
      bytes memory data = _createLzData(false, _eidSafeProxy, _owners, _threshold, 0, new uint32[](0));
      address refundAddress = address(this);
      uint256 nativeFee = _broadcastToEids(eid, data, options, refundAddress, providedFee);
      providedFee -= nativeFee;
    }
    address topLevelAddress = getAddressOnEid(proxyCreationParams[SafeProxy(payable(msg.sender))], 0);
    emit EmitNewState(topLevelAddress, _owners, _threshold);
  }

  // create and broadcast message to lz
  function _broadcastToEids(
    uint32 eid,
    bytes memory data,
    bytes memory options,
    address refundAddress,
    uint256 providedFee
  ) internal returns (uint256 nativeFee) {
    MessagingReceipt memory receipt =
      _lzSend(eid, data, options, MessagingFee({nativeFee: providedFee, lzTokenFee: 0}), refundAddress);

    nativeFee = receipt.fee.nativeFee;
  }

  /**
   *  @dev Batch send requires overriding this function from OAppSender because the msg.value contains multiple fees
   */
  function _payNative(uint256 _nativeFee) internal virtual override returns (uint256 nativeFee) {
    // TODO modify address(this).balance to reflect the user's balance
    if (msg.value + address(this).balance < _nativeFee) revert NotEnoughNative(msg.value);
    return _nativeFee;
  }

  function _getPeerOrRevert(uint32) internal view virtual override returns (bytes32) {
    return bytes32(uint256(uint160(address(_syncModule))));
  }

  function allowInitializePath(Origin calldata origin) public view virtual override returns (bool) {
    return _getPeerOrRevert(origin.srcEid) == origin.sender;
  }

  function _lzReceive(Origin calldata _origin, bytes32, bytes calldata _message, address, bytes calldata)
    internal
    virtual
    override
  {
    (
      bool isCreate,
      address _singletonOrSafeProxy,
      address[] memory _owners,
      uint256 _threshold,
      uint96 nonce,
      uint32[] memory eids
    ) = abi.decode(_message, (bool, address, address[], uint256, uint96, uint32[]));

    if (isCreate == true) {
      // add the origin eid
      uint32[] memory newEids = new uint32[](eids.length + 1);
      for (uint256 i = 0; i < eids.length; i++) {
        newEids[i] = eids[i];
      }
      newEids[eids.length] = _origin.srcEid;

      // here _singletonOrSafeProxy is singleton
      _initDeployProxy(_singletonOrSafeProxy, _owners, _threshold, nonce, newEids); // TODO add origin eid
    } else {
      // here _singletonOrSafeProxy is safeProxy
      _updateStateSetup(SafeProxy(payable(_singletonOrSafeProxy)), _owners, _threshold);
    }
  }

  /**
   * @dev Quotes the gas needed to pay for the full omniEid transaction.
   * @return fees Estimated gas fee in native gas.
   */
  function quote(address _singleton, address[] memory _owners, uint256 _threshold, uint96 nonce, uint32[] memory eids)
    public
    view
    returns (uint256[] memory fees)
  {
    bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(150_000, 0);
    fees = new uint256[](eids.length);

    for (uint32 i = 0; i < eids.length; i++) {
      uint32 eid = eids[i];
      uint32[] memory newEids = _removeEidFromList(eids, eid);
      bytes memory data = _createLzData(true, _singleton, _owners, _threshold, nonce, newEids);
      fees[i] = _quote(eid, data, options, false).nativeFee;
    }
  }

  mapping(address => address[]) prevOwners;
  mapping(address => uint256) prevThreshold;

  function checkTransaction(
    address,
    uint256,
    bytes memory,
    Enum.Operation,
    uint256,
    uint256,
    uint256,
    address,
    address payable,
    bytes memory,
    address
  ) external {
    _saveState();
  }

  function checkAfterExecution(bytes32, bool) external {
    _checkStateChange();
  }

  function checkModuleTransaction(address, uint256, bytes memory, Enum.Operation, address)
    external
    returns (bytes32 moduleTxHash)
  {
    // TODO reactivate later
    // _saveState();
  }

  function checkAfterModuleExecution(bytes32, bool) external {
    // TODO reactivate later
    // _checkStateChange();
  }

  function _saveState() internal {
    prevOwners[msg.sender] = ISafe(msg.sender).getOwners();
    prevThreshold[msg.sender] = ISafe(msg.sender).getThreshold();
  }

  function _checkStateChange() internal {
    address[] memory newOwners = ISafe(msg.sender).getOwners();
    uint256 newThreshold = ISafe(msg.sender).getThreshold();

    // check if signers are still the same
    if (
      keccak256(abi.encodePacked(newOwners)) != keccak256(abi.encodePacked(prevOwners[msg.sender]))
        || newThreshold != prevThreshold[msg.sender]
    ) {
      // owners or threshold changed, call lz
      _broadcastNewStateToEids(newOwners, newThreshold);
    }

    delete prevOwners[msg.sender];
    delete prevThreshold[msg.sender];
  }

  function declarePeer(uint32 eid) external onlyOwner {
    emit PeerSet(eid, bytes32(uint256(uint160(address(this)))));
  }
}
