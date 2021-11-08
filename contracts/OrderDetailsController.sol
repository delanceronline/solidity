// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductController.sol';
import './MarketplaceController.sol';
import './OrderModel.sol';

/*
------------------------------------------------------------------------------------

This is the controller class for the order details access which mainly gets access to the order model.

------------------------------------------------------------------------------------
*/

contract OrderDetailsController {
  
  using SafeMath for uint256;

  address public modelAddress;

  // Administrator only modifier
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in order details controller");
    _; 

  }

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // ---------------------------------------
  // admin only functions
  // ---------------------------------------

  // set if a deal can be extended to be finalized a bit later
  function setDealExtensionAllowed(uint did, bool flag) external adminOnly
  {
    OrderModel model = OrderModel(Model(modelAddress).orderModelAddress());
    require(did < model.getTotalDealCount());

    model.setDealFlag(did, 0, flag);
  }

  // set if direct deal rating is allowed
  function setDirectDealRatingAllowed(bool isAllowed) external adminOnly
  {
    OrderModel(Model(modelAddress).orderModelAddress()).setDirectDealRatingAllowed(isAllowed);
  }

  // ---------------------------------------
  // ---------------------------------------

  // get a list of votes to a seller
  function getDealVotes(address target) public view returns (SharedStructs.DealVote[] memory)
  {
    require(target != address(0));

    return OrderModel(Model(modelAddress).orderModelAddress()).getDealVotes(target);
  }

  // get the number of votes to a seller of an item
  function getNumOfDealVotesOfItem(uint igi) public view returns (uint)
  {
    //require(target != address(0));

    address target = ProductController(Model(modelAddress).productControllerAddress()).getItemOwner(igi);

    uint count = 0;

    SharedStructs.DealVote[] memory votes = OrderModel(Model(modelAddress).orderModelAddress()).getDealVotes(target);
    for(uint i = 0; i < votes.length; i++)
    {
      if(votes[i].itemGlobalIndex == igi)
        count++;
    }

    return count;
  }

  // get a list of votes to a seller of an item
  function getDealVotesOfItem(uint igi) external view returns (SharedStructs.DealVote[] memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    uint numOfDealVotes = getNumOfDealVotesOfItem(igi);
    if(numOfDealVotes == 0)
    {
      SharedStructs.DealVote[] memory nothing;
      return nothing;
    }

    SharedStructs.DealVote[] memory votes = new SharedStructs.DealVote[](numOfDealVotes);

    address target = ProductController(Model(modelAddress).productControllerAddress()).getItemOwner(igi);
    SharedStructs.DealVote[] memory allSellerVotes = orderModel.getDealVotes(target);

    uint count = 0;
    for(uint i = 0; i < allSellerVotes.length; i++)
    {
      if(allSellerVotes[i].itemGlobalIndex == igi)
      {
        votes[count] = allSellerVotes[i];
        count++;
      }
    }

    return votes;
  }

  // returns if a deal has been voted
  function isDealVoted(address target, uint dealGlobalIndex) external view returns (bool)
  {
    SharedStructs.DealVote[] memory votes = OrderModel(Model(modelAddress).orderModelAddress()).getDealVotes(target);

    for(uint i = 0; i < votes.length; i++)
    {
      if(votes[i].dealGlobalIndex == dealGlobalIndex)
        return true;
    }

    return false;
  }

  function getDeals(address owner) external view returns (uint[] memory)
  {
    require(owner != address(0));

    return OrderModel(Model(modelAddress).orderModelAddress()).getDeals(owner);
  }

  // get number of created deals of a user
  function numOfCreatedDeals(address owner) external view returns (uint)
  {
    require(owner != address(0));

    return OrderModel(Model(modelAddress).orderModelAddress()).getDealCount(owner);
  }

  // get number of finalized deals of a seller
  function getNumOfFinalizedDeals(address seller) public view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();
    uint[] memory dealIndices = orderModel.getDeals(seller);

    uint count = 0;

    for(uint i = 0; i < dealIndices.length; i++)
    {
      if(allDeals[dealIndices[i]].flags[2] == true)
        count++;
    }

    return count;
  }

  function getNumOfFinalizedDealsOfItem(uint igi) public view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();

    address seller = ProductController(Model(modelAddress).productControllerAddress()).getItemOwner(igi);
    uint[] memory dealIndices = orderModel.getDeals(seller);

    uint count = 0;

    for(uint i = 0; i < dealIndices.length; i++)
    {
      if(allDeals[dealIndices[i]].flags[2] == true && allDeals[dealIndices[i]].numericalData[5] == igi)
        count++;
    }

    return count;
  }

  // get a list of finalized deals of a user
  // flag --- 0, both as a buyer or seller
  // flag --- 1, as a buyer
  // flag --- 2, as a seller
  function getFinalizedDeals(address user, uint8 flag) external view returns (SharedStructs.Deal[] memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory deals = new SharedStructs.Deal[](getNumOfFinalizedDeals(user));

    uint[] memory dealIndices = orderModel.getDeals(user);
    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();

    uint count = 0;
    for(uint i = 0; i < dealIndices.length; i++)
    {
      if(allDeals[dealIndices[i]].flags[2] == true)
      {
        if(flag == 0)
        {
          deals[count] = allDeals[dealIndices[i]];
          count++;        
        }
        else if(flag == 1 && allDeals[dealIndices[i]].roles[0] == user)
        {
          deals[count] = allDeals[dealIndices[i]];
          count++;
        }
        else if(flag == 2 && allDeals[dealIndices[i]].roles[1] == user)
        {
          deals[count] = allDeals[dealIndices[i]];
          count++;        
        }
      }
    }

    return deals;
  }

  // get a list of finalized deals of an item of a seller 
  function getFinalizedDealsOfItem(uint igi) external view returns (SharedStructs.Deal[] memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());
    address seller = ProductController(Model(modelAddress).productControllerAddress()).getItemOwner(igi);

    uint numOfFinalizedDeals = getNumOfFinalizedDealsOfItem(igi);
    if(numOfFinalizedDeals == 0)
    {
      SharedStructs.Deal[] memory nothing;
      return nothing;
    }

    SharedStructs.Deal[] memory deals = new SharedStructs.Deal[](numOfFinalizedDeals);

    uint[] memory dealIndices = orderModel.getDeals(seller);
    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();

    uint count = 0;
    for(uint i = 0; i < dealIndices.length; i++)
    {
      if(allDeals[dealIndices[i]].flags[2] == true && allDeals[dealIndices[i]].numericalData[5] == igi)
      {
        deals[count] = allDeals[dealIndices[i]];
        count++;
      }
    }

    return deals;
  }

  function getDeal(uint dealGlobalIndex) external view returns (SharedStructs.Deal memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();
    return allDeals[dealGlobalIndex];
  }

  function getDealShippingNote(uint dealGlobalIndex) external view returns (string memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();
    return allDeals[dealGlobalIndex].shippingNote;
  }

  function getDealBuyerNote(uint dealGlobalIndex) external view returns (string memory)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    SharedStructs.Deal[] memory allDeals = orderModel.getAllDeals();
    return allDeals[dealGlobalIndex].buyerNote;
  }

  function getDealDispute(uint dealGlobalIndex) external view returns (SharedStructs.DealDispute memory)
  {
    return OrderModel(Model(modelAddress).orderModelAddress()).getDealDispute(dealGlobalIndex);
  }

  function getDisputedDealGlobalIndices() external view returns (uint[] memory)
  {
    return OrderModel(Model(modelAddress).orderModelAddress()).getDisputedDealGlobalIndices();
  }

  // get basic details of a deal
  function getDealBasicDetails(uint localIndex) external view returns (uint, uint, uint, uint, uint, uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);

    return (
      orderModel.getDealNumericalData(dealIndex, 6),
      orderModel.getDealNumericalData(dealIndex, 5),
      orderModel.getDealNumericalData(dealIndex, 0),
      orderModel.getDealNumericalData(dealIndex, 7),
      orderModel.getDealNumericalData(dealIndex, 8),
      dealIndex
    );
  }

  // get basic details of a deal by global deal index
  function getDealBasicDetailsByDealIndex(uint dealIndex) external view returns (uint, uint, uint, uint, uint, uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    require(dealIndex < orderModel.getTotalDealCount());
    
    return (
      orderModel.getDealNumericalData(dealIndex, 6),  // quantity
      orderModel.getDealNumericalData(dealIndex, 5),  // item global index
      orderModel.getDealNumericalData(dealIndex, 0),  // activation time
      orderModel.getDealNumericalData(dealIndex, 7),  // total amount
      orderModel.getDealNumericalData(dealIndex, 8),  // market commission percent
      dealIndex
    );
  }

  // get global deal index from a seller with local deal index given
  function getDealIndex(uint localIndex) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[tx.origin].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    return orderModel.getDealIndex(msg.sender, localIndex);
  }

  // get global item index of a deal of a seller
  function getDealGlobalItemIndex(uint localIndex) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealNumericalData(dealIndex, 5);
  }

  // get flag value of a deal of a seller
  function readFlag(uint localIndex, uint8 flagIndex) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    // flagIndex < 11 --- flag index is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender) && flagIndex < 11);

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealFlag(dealIndex, flagIndex);
  }

  // check if the caller is the seller of a deal
  function isDealSeller(uint localIndex) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealRole(dealIndex, 1) == msg.sender;
  }

  // get the seller address of a deal
  function getDealSeller(uint localIndex) external view returns (address)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealRole(dealIndex, 1);
  }

  // check if the caller is the buyer of a deal
  function isDealBuyer(uint localIndex) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealRole(dealIndex, 0) == msg.sender;
  }

  // get the buyer address of a deal
  function getDealBuyer(uint localIndex) external view returns (address)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return orderModel.getDealRole(dealIndex, 0);
  }

  // check if the dispute period of a deal expired
  function isDealDisputePeriodExpired(uint localIndex) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);
    return (block.number.sub(orderModel.getDealNumericalData(dealIndex, 1)) > orderModel.getDealNumericalData(dealIndex, 4));
  }

  // get the remaining number of blocks before dispute period expired
  function getDisputePeriodRemains(uint localIndex) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);

    uint timeElapsed = block.number.sub(orderModel.getDealNumericalData(dealIndex, 1));
    if(timeElapsed < orderModel.getDealNumericalData(dealIndex, 4))
    {
      return orderModel.getDealNumericalData(dealIndex, 4).sub(timeElapsed);
    }

    return 0;
  }

  // get the remaining number of blocks before cancellation period expired
  function getCancellationPeriodRemains(uint localIndex) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localIndex < orderModel.getDealCount(msg.sender));

    uint dealIndex = orderModel.getDealIndex(msg.sender, localIndex);

    if(orderModel.getDealFlag(dealIndex, 4))
    {
      uint timeElapsed = block.number.sub(orderModel.getDealNumericalData(dealIndex, 2));

      uint shippingPeriod = ProductController(Model(modelAddress).productControllerAddress()).getShippingPeriodOfItem(orderModel.getDealNumericalData(dealIndex, 5));
      if(timeElapsed < shippingPeriod)
      {
        return shippingPeriod.sub(timeElapsed);
      }
    }

    return 0;
  }  
}