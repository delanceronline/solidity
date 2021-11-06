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
  
  // controller only modifier
  modifier controllerOnly()
  {
    require(Model(modelAddress).isController(msg.sender), "Controller access only in main model");
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

  mapping (address => SharedStructs.DealVote[]) public dealVotes;
  mapping (address => SharedStructs.ModerationVote[]) public moderationVotes;

  mapping (uint => SharedStructs.DealDispute) public dealDisputes;
  uint[] public disputedDealGlobalIndices;

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------

  function getAllDeals() external view controllerOnly returns (SharedStructs.Deal[] memory)
  {
    return deals;
  }

  function getDeals(address owner) external view controllerOnly returns (uint[] memory)
  {
    return dealOwners[owner];
  }

  function addDealDispute(uint dealGlobalIndex, string calldata note) external controllerOnly
  {
    SharedStructs.DealDispute memory dispute;
    dispute.isResolved = false;
    dispute.shouldRefund = false;
    dispute.note = note;
    dispute.blockNumber = block.number;

    dealDisputes[dealGlobalIndex] = dispute;
  }

  function editDealDispute(uint dealGlobalIndex, bool isResolved, bool shouldRefund, uint handlingFee, string calldata note) external controllerOnly
  {
    SharedStructs.DealDispute storage dispute = dealDisputes[dealGlobalIndex];
    dispute.isResolved = isResolved;
    dispute.shouldRefund = shouldRefund;
    dispute.handlingFee = handlingFee;
    dispute.note = note;
    dispute.blockNumber = block.number;
  }

  function setDealDisputeResolved(uint dealGlobalIndex, bool shouldRefund, uint handlingFee) external controllerOnly
  {
    SharedStructs.DealDispute storage dispute = dealDisputes[dealGlobalIndex];
    dispute.shouldRefund = shouldRefund;
    dispute.handlingFee = handlingFee;
  }

  function getDealDispute(uint dealGlobalIndex) external view controllerOnly returns (SharedStructs.DealDispute memory)
  {
    return dealDisputes[dealGlobalIndex];
  }

  function addDisputedDealGlobalIndex(uint globalDealIndex) external controllerOnly
  {
    disputedDealGlobalIndices.push(globalDealIndex);
  }

  function getDisputedDealGlobalIndices() external view controllerOnly returns (uint[] memory)
  {
    return disputedDealGlobalIndices;
  }

  function addDealVote(address target, address voter, uint itemGlobalIndex, uint dealGlobalIndex, uint8 rating, bytes calldata review) external controllerOnly
  {
    require(target != address(0));
    require(voter != address(0));

    SharedStructs.DealVote memory vote;
    vote.voter = voter;
    vote.itemGlobalIndex = itemGlobalIndex;
    vote.dealGlobalIndex = dealGlobalIndex;
    vote.rating = rating;
    vote.review = review;

    dealVotes[target].push(vote);
  }

  function editDealVote(address target, address voter, uint itemGlobalIndex, uint dealGlobalIndex, uint8 rating, bytes calldata review) external controllerOnly
  {
    require(target != address(0));
    require(voter != address(0));

    SharedStructs.DealVote[] storage votes = dealVotes[target];

    for(uint i = 0; i < votes.length; i++)
    {
      if(votes[i].itemGlobalIndex == itemGlobalIndex && votes[i].dealGlobalIndex == dealGlobalIndex)
      {
        votes[i].voter = voter;
        votes[i].itemGlobalIndex = itemGlobalIndex;
        votes[i].dealGlobalIndex = dealGlobalIndex;
        votes[i].rating = rating;
        votes[i].review = review;
        
        break; 
      }
    }
  }

  function getDealVotes(address target) external view controllerOnly returns (SharedStructs.DealVote[] memory)
  {
    require(target != address(0));

    return dealVotes[target];
  }

  function addModerationVote(address target, address voter, uint dealGlobalIndex, uint8 rating, bytes calldata review) external controllerOnly
  {
    require(target != address(0));
    require(voter != address(0));

    SharedStructs.ModerationVote memory vote;
    vote.voter = voter;
    vote.dealGlobalIndex = dealGlobalIndex;
    vote.rating = rating;
    vote.review = review;

    moderationVotes[target].push(vote);
  }

  function editModerationVote(address target, address voter, uint dealGlobalIndex, uint8 rating, bytes calldata review) external controllerOnly
  {
    require(target != address(0));
    require(voter != address(0));

    SharedStructs.ModerationVote[] storage votes = moderationVotes[target];

    for(uint i = 0; i < votes.length; i++)
    {
      if(votes[i].dealGlobalIndex == dealGlobalIndex)
      {
        votes[i].voter = voter;
        votes[i].dealGlobalIndex = dealGlobalIndex;
        votes[i].rating = rating;
        votes[i].review = review;
        
        break; 
      }
    }
  }

  function getModerationVotes(address target) external view controllerOnly returns (SharedStructs.ModerationVote[] memory)
  {
    require(target != address(0));

    return moderationVotes[target];
  }



  // set buyer note of a deal
  function setDealBuyerNote(uint dealGlobalIndex, string calldata note) external controllerOnly
  {
    deals[dealGlobalIndex].buyerNote = note;
  }

  // get buyer note of a deal
  function getDealBuyerNote(uint dealGlobalIndex) external view controllerOnly returns (string memory)
  {
    return deals[dealGlobalIndex].buyerNote;
  }

  // set shipping note of a deal
  function setDealShippingNote(uint dealGlobalIndex, string calldata note) external controllerOnly
  {
    deals[dealGlobalIndex].shippingNote = note;
  }

  // get shipping note of a deal
  function getDealShippingNote(uint dealGlobalIndex) external view controllerOnly returns (string memory)
  {
    return deals[dealGlobalIndex].shippingNote;
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
  function setDealRole(uint dealIndex, uint8 index, address addr) external controllerOnly
  {
    require(index >= 0 && index < 4);
    require(dealIndex <  deals.length);

    deals[dealIndex].roles[index] = addr;
  }

  // set the numercial data value of a deal
  function setDealNumericalData(uint dealIndex, uint8 index, uint value) external controllerOnly
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    deals[dealIndex].numericalData[index] = value;
  }

  // set the flag value of a deal
  function setDealFlag(uint dealIndex, uint8 index, bool value) external controllerOnly
  {
    require(index >= 0 && index < 11);
    require(dealIndex <  deals.length);

    deals[dealIndex].flags[index] = value;
  }

  // set if direct deal rating to items is available
  function setDirectDealRatingAllowed(bool isAllowed) public controllerOnly
  {
    isDirectDealRatingAllowed = isAllowed;
  }

  // add a global deal index to a seller
  function addDealIndex(address seller, uint dealIndex) external controllerOnly
  {
    require(seller != address(0));

    dealOwners[seller].push(dealIndex);
  }

  // remove a global deal index from a seller
  function removeDealIndex(address seller, uint position) external controllerOnly
  {
    require(seller != address(0));
    require(position < dealOwners[seller].length);

    dealOwners[seller][position] = dealOwners[seller][dealOwners[seller].length - 1];
    //dealOwners[seller].length--;
    dealOwners[seller].pop();
  }

  function addDeal(SharedStructs.Deal calldata deal) external controllerOnly returns (uint)
  {
    deals.push(deal);
    return deals.length - 1;
  }

}