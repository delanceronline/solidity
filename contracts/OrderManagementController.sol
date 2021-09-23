pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductController.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';
import './MarketplaceController.sol';

contract OrderManagementController {
  
  using SafeMath for uint256;

  address public modelAddress;

  modifier moderatorOnly() {

    require(Model(modelAddress).isModerator(msg.sender), "Moderator access only in order management controller");
    _;

  }

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  function resolveDispute(uint dealIndex, bool shouldRefund) external moderatorOnly
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    require(dealIndex < orderModel.getTotalDealCount());

    orderModel.setDealFlag(dealIndex, 6, true);
    orderModel.setDealFlag(dealIndex, 7, shouldRefund);

    // restore quantity on held
    ProductController(Model(modelAddress).productControllerAddress()).plusProductQuantity(orderModel.getDealNumericalData(dealIndex, 5), orderModel.getDealNumericalData(dealIndex, 6));    

    uint totalAmount = orderModel.getDealNumericalData(dealIndex, 7);
    uint handlingFee = totalAmount.mul(Model(modelAddress).moderatorHandlingFeeRate().div(100));

    if(handlingFee > 0)
    {        
      orderModel.setDealNumericalData(dealIndex, 7, totalAmount.sub(handlingFee));        
      
      // send handling fee to moderator
      OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(msg.sender, handlingFee);
    }

    EventModel(Model(modelAddress).eventModelAddress()).onDisputeResolvedEmit(dealIndex, shouldRefund, handlingFee);
  }

  // seller functions

  function setDealShipped(uint i, string calldata shippingNote) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[msg.sender].length --- deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    require(!orderModel.getDealFlag(dealIndex, 1));

    // !deal.flags[1] && !deal.flags[3] --- Not shipped AND not cancelled
    // msg.sender == deal.roles[1] --- Only seller can ship a deal.
    require(!orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 3) && msg.sender == orderModel.getDealRole(dealIndex, 1));

    orderModel.setDealFlag(dealIndex, 1, true);
    orderModel.setDealNumericalData(dealIndex, 1, block.number);

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
  function acceptDeal(uint i) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[msg.sender].length --- deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);
    require(!orderModel.getDealFlag(dealIndex, 1));

    // !deal.flags[4] && !deal.flags[3] --- Not accepted yet AND not cancelled
    // msg.sender == deal.roles[1] --- Only seller can accept a deal.
    require(!orderModel.getDealFlag(dealIndex, 4) && !orderModel.getDealFlag(dealIndex, 3) && msg.sender == orderModel.getDealRole(dealIndex, 1));

    orderModel.setDealFlag(dealIndex, 4, true);
    orderModel.setDealNumericalData(dealIndex, 2, block.number);
  }

  function rejectDeal(uint i) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);

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

  function disputeDeal(uint i, string calldata details) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);

    // block.number.sub(deal.numericalData[1]) <= deal.numericalData[4] --- Only can raise a dispute within safe period.
    // deal.flags[4] && deal.flags[1] && !deal.flags[2] && !deal.flags[5] --- Order must be accepted by seller AND shipped by seller AND not finalzied AND not under dispute.
    // tx.origin == deal.roles[0] --- Only buyer can dispute a deal within safe period.
    require(block.number.sub(orderModel.getDealNumericalData(dealIndex, 1)) <= orderModel.getDealNumericalData(dealIndex, 4) && (orderModel.getDealFlag(dealIndex, 4) && orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 2) && !orderModel.getDealFlag(dealIndex, 5)) && msg.sender == orderModel.getDealRole(dealIndex, 0));

    orderModel.setDealFlag(dealIndex, 5, true);
    EventModel(Model(modelAddress).eventModelAddress()).onDisputeDealEmit(dealIndex, details);
  }

  function extendDealSafeDuration(uint i) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);

    // Extension is allowed AND only buyer can extend a deal AND only can extend a deal after item shipped AND not under dispute AND not finalized.
    require(orderModel.getDealFlag(dealIndex, 0) && msg.sender == orderModel.getDealRole(dealIndex, 0) && orderModel.getDealFlag(dealIndex, 1) && !orderModel.getDealFlag(dealIndex, 5) && !orderModel.getDealFlag(dealIndex, 2));

    uint remains = (orderModel.getDealNumericalData(dealIndex, 4).add(orderModel.getDealNumericalData(dealIndex, 1))).sub(block.number);
    orderModel.setDealNumericalData(dealIndex, 4, orderModel.getDealNumericalData(dealIndex, 4).add(orderModel.getDealNumericalData(dealIndex, 3).sub(remains)));
  }

  function cancelDeal(uint i) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound.
    require(i < orderModel.getTotalDealCount());

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);

    // !deal.flags[3] && !deal.flags[2] --- Not cancelled AND not finalized
    // tx.origin == deal.roles[0] --- Only buyer can cancel a deal.
    // !deal.flags[4] -> Only can cancel a deal before accepted by seller OR
    // deal.flags[4] && !deal.flags[1] && (block.number - deal.numericalData[2] > deal.numericalData[9]) -> 
    // time from deal accepted should expire shipping period but not shipped yet OR
    // deal.flags[5] && (deal.flags[6] && deal.flags[7]) -> under dispute and resolved by moderator to buyerz favour
    require(!orderModel.getDealFlag(dealIndex, 3) && !orderModel.getDealFlag(dealIndex, 2) && msg.sender == orderModel.getDealRole(dealIndex, 0) && (!orderModel.getDealFlag(dealIndex, 4) || (orderModel.getDealFlag(dealIndex, 4) && !orderModel.getDealFlag(dealIndex, 1) && (block.number - orderModel.getDealNumericalData(dealIndex, 2) > orderModel.getDealNumericalData(dealIndex, 9))) || (orderModel.getDealFlag(dealIndex, 5) && (orderModel.getDealFlag(dealIndex, 6) && orderModel.getDealFlag(dealIndex, 7)))));

    orderModel.setDealFlag(dealIndex, 3, true);
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(msg.sender, orderModel.getDealNumericalData(dealIndex, 7));

    ProductController(Model(modelAddress).productControllerAddress()).plusProductQuantity(orderModel.getDealNumericalData(dealIndex, 5), orderModel.getDealNumericalData(dealIndex, 6));
  }

  function submitRatingAndReview(uint i, uint8 rating, bytes calldata review) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // 'deal count is out of bound AND rating score should be greater than zero.'
    require(i < orderModel.getTotalDealCount() && rating > 0);

    uint dealIndex = orderModel.getDealIndex(msg.sender, i);

    // !deal.flags[10] || isDirectDealRatingAllowed --- non direct deal or rating is allowed
    // deal.flags[2] --- deal was finalized.
    // tx.origin == deal.roles[0] || tx.origin == deal.roles[1] --- either seller or buyer can rate.
    require((!orderModel.getDealFlag(dealIndex, 10) || OrderModel(Model(modelAddress).orderModelAddress()).isDirectDealRatingAllowed()) && orderModel.getDealFlag(dealIndex, 2) && (msg.sender == orderModel.getDealRole(dealIndex, 0) || msg.sender == orderModel.getDealRole(dealIndex, 1)));

    if(msg.sender == orderModel.getDealRole(dealIndex, 0))
    {
      // buyer rates seller

      // deal was rated.
      require(!orderModel.getDealFlag(dealIndex, 8));

      orderModel.setDealFlag(dealIndex, 8, true);

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

  // ---------------------------------------
  // ---------------------------------------    
  
}