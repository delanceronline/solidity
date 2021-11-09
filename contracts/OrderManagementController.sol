// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductController.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';
import './MarketplaceController.sol';

/*
------------------------------------------------------------------------------------

This is the controller class for the order management which mainly gets access to the order model.

------------------------------------------------------------------------------------
*/

contract OrderManagementController {
  
  using SafeMath for uint256;

  address public modelAddress;

  // moderator only modifier
  modifier moderatorOnly() {

    require(Model(modelAddress).isModerator(msg.sender), "Moderator access only in order management controller");
    _;

  }

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // called by moderator only and set the dispute case result of a deal
  function resolveDispute(uint globalDealIndex, bool shouldRefund) external moderatorOnly
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    require(globalDealIndex < orderModel.getTotalDealCount());

    orderModel.setDealFlag(globalDealIndex, 6, true);
    orderModel.setDealFlag(globalDealIndex, 7, shouldRefund);

    uint totalAmount = orderModel.getDealNumericalData(globalDealIndex, 7);
    uint handlingFee = totalAmount.mul(MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateModeratorHandlingFeeRate(totalAmount)).div(100);

    if(handlingFee > 0)
    {        
      orderModel.setDealNumericalData(globalDealIndex, 7, totalAmount.sub(handlingFee));        
      
      // send handling fee to moderator
      OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(msg.sender, handlingFee);
    }

    orderModel.setDealDisputeResolved(globalDealIndex, shouldRefund, handlingFee);
    EventModel(Model(modelAddress).eventModelAddress()).onDisputeResolvedEmit(globalDealIndex, shouldRefund, handlingFee);
  }

  // seller ships the deal
  function setDealShipped(uint localDealIndex, string calldata shippingNote) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localDealIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(tx.origin, localDealIndex);
    require(!orderModel.getDealFlag(dealIndex, 1));

    // !deal.flags[1] && !deal.flags[3] --- Not shipped AND not cancelled
    // msg.sender == deal.roles[1] --- Only seller can ship a deal.
    require(!orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 3) && msg.sender == orderModel.getDealRole(dealIndex, 1));

    orderModel.setDealFlag(dealIndex, 1, true);
    orderModel.setDealNumericalData(dealIndex, 1, block.number);
    orderModel.setDealShippingNote(dealIndex, shippingNote);

    EventModel(Model(modelAddress).eventModelAddress()).onDealSetShippingNoteEmit(dealIndex, shippingNote);

    // check if a direct deal, yes then finalize the deal, sending fund to seller.
    if(orderModel.getDealFlag(dealIndex, 10))
    {
      orderModel.setDealFlag(dealIndex, 2, true);
      EventModel(Model(modelAddress).eventModelAddress()).onDealFinalizedEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 5), dealIndex);

      ProductController(Model(modelAddress).productControllerAddress()).addItemDealCountByOne(orderModel.getDealNumericalData(dealIndex, 5));

      //tx.origin.transfer(deal.numericalData[7]);
      OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(msg.sender, orderModel.getDealNumericalData(dealIndex, 7));
    }
  }
  
  // seller accepts a deal request from a buyer
  function acceptDeal(uint localDealIndex) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localDealIndex < dealOwners[msg.sender].length --- deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);
    require(!orderModel.getDealFlag(dealIndex, 1));

    // !deal.flags[4] && !deal.flags[3] --- Not accepted yet AND not cancelled
    // msg.sender == deal.roles[1] --- Only seller can accept a deal.
    require(!orderModel.getDealFlag(dealIndex, 4) && !orderModel.getDealFlag(dealIndex, 3) && msg.sender == orderModel.getDealRole(dealIndex, 1));

    orderModel.setDealFlag(dealIndex, 4, true);
    orderModel.setDealNumericalData(dealIndex, 2, block.number);
  }

  // seller rejects a deal
  function rejectDeal(uint localDealIndex) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // localDealIndex < dealOwners[tx.origin].length --- deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // !deal.flags[3] && !deal.flags[2] --- Not cancelled AND not finalized
    // tx.origin == deal.roles[1] --- Only seller can refund a deal.
    require(!orderModel.getDealFlag(dealIndex, 3) && !orderModel.getDealFlag(dealIndex, 2) && msg.sender == orderModel.getDealRole(dealIndex, 1));

    // restore quantity on held
    ProductController(Model(modelAddress).productControllerAddress()).plusProductQuantity(orderModel.getDealNumericalData(dealIndex, 5), orderModel.getDealNumericalData(dealIndex, 6));

    if(orderModel.getDealFlag(dealIndex, 5))
    {
      // if the deal is already in dispute, resolve it.
      orderModel.setDealFlag(dealIndex, 6, true);
      orderModel.setDealFlag(dealIndex, 7, true);

      orderModel.setDealDisputeResolved(dealIndex, true, 0);
      EventModel(Model(modelAddress).eventModelAddress()).onDisputeResolvedEmit(dealIndex, true, 0);
    }
    else
    {
      // otherwise refund it directly
      orderModel.setDealFlag(dealIndex, 3, true);
      orderModel.setDealFlag(dealIndex, 4, false);

      OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 7));
    }
  }

  // called by the buyer to raise a dispute of a deal
  function disputeDeal(uint localDealIndex, string calldata details) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // block.number.sub(deal.numericalData[1]) <= deal.numericalData[4] --- Only can raise a dispute within safe period.
    // deal.flags[4] && deal.flags[1] && !deal.flags[2] && !deal.flags[5] --- Order must be accepted by seller AND shipped by seller AND not finalzied AND not under dispute.
    // tx.origin == deal.roles[0] --- Only buyer can dispute a deal within safe period.
    require(block.number.sub(orderModel.getDealNumericalData(dealIndex, 1)) <= orderModel.getDealNumericalData(dealIndex, 4) && (orderModel.getDealFlag(dealIndex, 4) && orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 2) && !orderModel.getDealFlag(dealIndex, 5)) && msg.sender == orderModel.getDealRole(dealIndex, 0));

    orderModel.setDealFlag(dealIndex, 5, true);
    orderModel.addDealDispute(dealIndex, details);

    uint[] memory indices = orderModel.getDisputedDealGlobalIndices();
    bool doesExist = false;
    for(uint i = 0; i < indices.length; i++)
    {
      if(indices[i] == dealIndex)
      {
        doesExist = true;
        break;
      }
    }
    if(!doesExist)
      orderModel.addDisputedDealGlobalIndex(dealIndex);

    EventModel(Model(modelAddress).eventModelAddress()).onDisputeDealEmit(dealIndex, details);
  }

  // called by buyer to extend the safe duration (to postpone finalization time)
  function extendDealSafeDuration(uint localDealIndex) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // Extension is allowed AND only buyer can extend a deal AND only can extend a deal after item shipped AND not under dispute AND not finalized.
    require(orderModel.getDealFlag(dealIndex, 0) && msg.sender == orderModel.getDealRole(dealIndex, 0) && orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 5) && !orderModel.getDealFlag(dealIndex, 2));

    uint remains = (orderModel.getDealNumericalData(dealIndex, 4).add(orderModel.getDealNumericalData(dealIndex, 1))).sub(block.number);
    orderModel.setDealNumericalData(dealIndex, 4, orderModel.getDealNumericalData(dealIndex, 4).add(orderModel.getDealNumericalData(dealIndex, 3).sub(remains)));
  }

  // buyer cancels a deal request
  function cancelDeal(uint localDealIndex) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(localDealIndex < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // !deal.flags[3] && !deal.flags[2] --- Not cancelled AND not finalized
    // msg.sender == deal.roles[0] --- Only buyer can cancel a deal.
    // !deal.flags[4] -> Only can cancel a deal before accepted by seller OR
    // deal.flags[4] && !deal.flags[1] && (block.number - deal.numericalData[2] > deal.numericalData[9]) -> 
    // time from deal accepted should expire shipping period but not shipped yet OR
    // deal.flags[5] && (deal.flags[6] && deal.flags[7]) -> under dispute and resolved by moderator to buyerz favour
    require(!orderModel.getDealFlag(dealIndex, 3) && !orderModel.getDealFlag(dealIndex, 2) && msg.sender == orderModel.getDealRole(dealIndex, 0) && (!orderModel.getDealFlag(dealIndex, 4) || (orderModel.getDealFlag(dealIndex, 4) && !orderModel.getDealFlag(dealIndex, 1) && (block.number - orderModel.getDealNumericalData(dealIndex, 2) > orderModel.getDealNumericalData(dealIndex, 9))) || (orderModel.getDealFlag(dealIndex, 5) && (orderModel.getDealFlag(dealIndex, 6) && orderModel.getDealFlag(dealIndex, 7)))));

    orderModel.setDealFlag(dealIndex, 3, true);
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(msg.sender, orderModel.getDealNumericalData(dealIndex, 7));

    ProductController(Model(modelAddress).productControllerAddress()).plusProductQuantity(orderModel.getDealNumericalData(dealIndex, 5), orderModel.getDealNumericalData(dealIndex, 6));
  }

  // buyer submits rating and review of a complete deal
  function submitRatingAndReview(uint localDealIndex, uint8 rating, bytes calldata review) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // 'deal count is out of bound AND rating score should be greater than zero.'
    require(localDealIndex < orderModel.getTotalDealCount() && rating > 0);

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // !deal.flags[10] || isDirectDealRatingAllowed --- non direct deal or rating is allowed
    // deal.flags[2] --- deal was finalized.
    // tx.origin == deal.roles[0] || tx.origin == deal.roles[1] --- either seller or buyer can rate.
    require((!orderModel.getDealFlag(dealIndex, 10) || OrderModel(Model(modelAddress).orderModelAddress()).isDirectDealRatingAllowed()) && orderModel.getDealFlag(dealIndex, 2) && (msg.sender == orderModel.getDealRole(dealIndex, 0) || msg.sender == orderModel.getDealRole(dealIndex, 1)));

    require(!orderModel.getDealFlag(dealIndex, 5), 'The deal was disputed before, unable to rate it.');

    if(msg.sender == orderModel.getDealRole(dealIndex, 0))
    {
      // buyer rates seller

      // deal was rated.
      require(!orderModel.getDealFlag(dealIndex, 8));

      orderModel.setDealFlag(dealIndex, 8, true);
      orderModel.addDealVote(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, rating, review);

      EventModel(Model(modelAddress).eventModelAddress()).onDealRatedByBuyerEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, orderModel.getDealRole(dealIndex, 0), rating, review);

      ProductController(Model(modelAddress).productControllerAddress()).addItemRatingScore(orderModel.getDealNumericalData(dealIndex, 5), rating);
    }
    else
    {
      // seller rates buyer

      // deal was rated.
      require(!orderModel.getDealFlag(dealIndex, 9));

      orderModel.setDealFlag(dealIndex, 9, true);
      EventModel(Model(modelAddress).eventModelAddress()).onDealRatedBySellerEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, orderModel.getDealRole(dealIndex, 0), rating, review);      
    }
  }
  
}