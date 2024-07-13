// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HoldsBalance {
  mapping(address => uint256) public balances;

  event Fund(address indexed eoa, uint256 amount);
  event Debit(address indexed eoa, uint256 amount);

  function _fund(address eoa, uint256 amount) internal {
    balances[eoa] += amount;
    emit Fund(eoa, amount);
  }

  function _debit(address eoa, uint256 amount) internal {
    balances[eoa] -= amount;
    emit Debit(eoa, amount);
  }  
}
