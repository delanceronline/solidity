pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './EventModel.sol';
import './ProductModel.sol';
import './Token.sol';

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

  // deal structure
  struct Deal{

    //0: buyer
    //1: seller
    //2: referee
    //3: moderator
    address[4] roles;

    
    //0: activationTime
    //1: shippedTime
    //2: acceptionTime
    //3: disputeExpiredDuration
    //4: totalDisputeExpiredDuration
    //5: itemGlobalIndex
    //6: quantity
    //7: amountTotal
    //8: market commission percent
    //9: shippingPeriod in blocks
    //10: moderator handling fee percent
    uint[11] numericalData;


    //0: isExtendingDealAllowed
    //1: isShipped
    //2: isFinalized
    //3: isCancelled
    //4: isAccepted
    //5: isDisputed
    //6: isDisputeResolved
    //7: shouldRefund
    //8: isRatedAndReviewedByBuyer
    //9: isRatedAndReviewedBySeller
    //10: isDirectDeal
    bool[11] flags;
    
  }

  // store all deals
  Deal[] internal deals;
  
  // store the relation of deal owners
  mapping (address => uint[]) public dealOwners;

  // direct deal rating flag
  bool public isDirectDealRatingAllowed;

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------

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
    dealOwners[seller].length--;
  }

  // create a deal instance and returns its global deal index
  function createDeal() external orderControllerOnly returns (uint)
  {
    Deal memory deal;
    deals.push(deal);

    require(deals.length > 0, "deals.length must be > zero.");

    return deals.length - 1;
  }

}