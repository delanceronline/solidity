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
  
  // set a tag for an item
  function addHashTag(uint localItemIndex, bytes32 lowerCaseHash, bytes32 originalHash, bytes calldata tag, bool isEnabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You don't have any items.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0, "You can only edit your own item.");

    require(model.getItemCategory(igi.sub(1)) != 0, 'Category id should be greater than zero.');

    model.addHashTag(lowerCaseHash, igi, tag, isEnabled);
    EventModel(Model(modelAddress).eventModelAddress()).onSetItemTagEmit(igi, lowerCaseHash, originalHash, tag, isEnabled);
  }  

  function enableHashTag(bytes32 lowerCaseHash, uint localItemIndex, bool isEnabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0, "You can only edit your own item.");

    require(model.getItemCategory(igi.sub(1)) != 0, 'Category id should be greater than zero.');

    model.enableHashTag(lowerCaseHash, igi, isEnabled);
    EventModel(Model(modelAddress).eventModelAddress()).onSetItemTagEmit(igi, lowerCaseHash, '', '', isEnabled);
  }

  function getHashTags(bytes32 lowerCaseHash) external view returns (SharedStructs.HashTag[] memory)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getHashTags(lowerCaseHash);
  }

  // set if an item is banned
  function setItemBanned(uint igi, bool isBanned) adminOnly external
  {
    ProductModel(Model(modelAddress).productModelAddress()).setItemIsBanned(igi, isBanned);    
  }
}