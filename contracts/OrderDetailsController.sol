pragma solidity >=0.4.21 <0.6.0;

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

  constructor(address addr) public
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

  // get number of deals of a user (the caller)
  function numOfDeals() external view returns (uint)
  {
    return OrderModel(Model(modelAddress).orderModelAddress()).getDealCount(msg.sender);
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