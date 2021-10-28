// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './EventModel.sol';
import './ProductModel.sol';
import './Token.sol';
import './SharedStructs.sol';

/*
------------------------------------------------------------------------------------

This is the model for the orders handling which is mainly accessible by the order controllers.

------------------------------------------------------------------------------------
*/

contract OrderModel {

  using SafeMath for uint256;

  address public modelAddress;

  // order controllers only modifier
  modifier orderControllerOnly() {

    require(msg.sender == Model(modelAddress).orderDetailsControllerAddress() || msg.sender == Model(modelAddress).orderManagementControllerAddress() || msg.sender == Model(modelAddress).orderSettlementControllerAddress(), "Order controller access only in order model");
    _;

  }
  
  // administrator only modifier
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in order model");
    _; 

  }

  

  // store all deals
  SharedStructs.Deal[] internal deals;
  
  // store the relation of deal owners
  mapping (address => uint[]) public dealOwners;

  // direct deal rating flag
  bool public isDirectDealRatingAllowed;

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------

  function getAllDeals() external view orderControllerOnly returns (SharedStructs.Deal[] memory)
  {
    return deals;
  }

  function getDeals(address owner) external view orderControllerOnly returns (uint[] memory)
  {
    return dealOwners[owner];
  }

  // get the number of deals made globally
  function getTotalDealCount() external view returns (uint)
  {
    return deals.length;
  }

  // get the number of deals made of a seller
  function getDealCount(address seller) external view returns (uint)
  {
    require(seller != address(0));

    return dealOwners[seller].length;
  }

  // get the global deal index of a deal from a seller
  function getDealIndex(address seller, uint position) external view returns (uint)
  {
    require(seller != address(0));
    require(position < dealOwners[seller].length);

    return dealOwners[seller][position];
  }

  // get all deal global indices of a seller
  function getDealIndices(address seller) public view returns (uint[] memory)
  {
    require(seller != address(0));

    return dealOwners[seller];
  }

  // get a role (seller, buyer, referee or moderator) of a deal
  function getDealRole(uint dealIndex, uint8 index) external view returns (address)
  {
    require(index >= 0 && index < 4);
    require(dealIndex <  deals.length);

    return deals[dealIndex].roles[index];
  }

  // get the numerical data value of a deal
  function getDealNumericalData(uint dealIndex, uint8 index) external view returns (uint)
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    return deals[dealIndex].numericalData[index];
  }

  // get the flag value of a deal
  function getDealFlag(uint dealIndex, uint8 index) external view returns (bool)
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    return deals[dealIndex].flags[index];
  }

  // set the role of a user in a deal
  function setDealRole(uint dealIndex, uint8 index, address addr) external orderControllerOnly
  {
    require(index >= 0 && index < 4);
    require(dealIndex <  deals.length);

    deals[dealIndex].roles[index] = addr;
  }

  // set the numercial data value of a deal
  function setDealNumericalData(uint dealIndex, uint8 index, uint value) external orderControllerOnly
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    deals[dealIndex].numericalData[index] = value;
  }

  // set the flag value of a deal
  function setDealFlag(uint dealIndex, uint8 index, bool value) external orderControllerOnly
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    deals[dealIndex].flags[index] = value;
  }

  // set if direct deal rating to items is available
  function setDirectDealRatingAllowed(bool isAllowed) public orderControllerOnly
  {
    isDirectDealRatingAllowed = isAllowed;
  }

  // add a global deal index to a seller
  function addDealIndex(address seller, uint dealIndex) external orderControllerOnly
  {
    require(seller != address(0));

    dealOwners[seller].push(dealIndex);
  }

  // remove a global deal index from a seller
  function removeDealIndex(address seller, uint position) external orderControllerOnly
  {
    require(seller != address(0));
    require(position < dealOwners[seller].length);

    dealOwners[seller][position] = dealOwners[seller][dealOwners[seller].length - 1];
    //dealOwners[seller].length--;
    dealOwners[seller].pop();
  }

  /*
  // create a deal instance and returns its global deal index
  function createDeal() external orderControllerOnly returns (uint)
  {
    SharedStructs.Deal memory deal;
    deals.push(deal);

    require(deals.length > 0, "deals.length must be > zero.");

    return deals.length - 1;
  }
  */

  function addDeal(SharedStructs.Deal calldata deal) external orderControllerOnly returns (uint)
  {
    deals.push(deal);
    return deals.length - 1;
  }

}