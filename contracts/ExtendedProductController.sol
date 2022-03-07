// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductModel.sol';
import './SharedStructs.sol';

/*
------------------------------------------------------------------------------------

This is the controller class for the items / products which mainly gets access to the product model.

------------------------------------------------------------------------------------
*/

contract ExtendedProductController {
  
  using SafeMath for uint256;

  address public modelAddress;

  // administrator only modifier
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product controller");
    _; 

  }

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // set if an item is banned
  function setItemBanned(uint igi, bool isBanned) adminOnly external
  {
    ProductModel(Model(modelAddress).productModelAddress()).setItemIsBanned(igi, isBanned);    
  }
}