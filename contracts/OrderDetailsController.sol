pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductController.sol';
import './MarketplaceController.sol';
import './OrderModel.sol';

contract OrderDetailsController {
  
  using SafeMath for uint256;

  address public modelAddress;

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

  function setDealExtensionAllowed(uint did, bool flag) external adminOnly
  {
    OrderModel model = OrderModel(Model(modelAddress).orderModelAddress());
    require(did < model.getTotalDealCount());

    model.setDealFlag(did, 0, flag);
  }

  function setDirectDealRatingAllowed(bool isAllowed) external adminOnly
  {
    OrderModel(Model(modelAddress).orderModelAddress()).setDirectDealRatingAllowed(isAllowed);
  }

  function numOfDeals() external view returns (uint)
  {
    return OrderModel(Model(modelAddress).orderModelAddress()).getDealCount(tx.origin);
  }

  function getDealBasicDetails(uint i) external view returns (uint, uint, uint, uint, uint, uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);

    return (
      orderModel.getDealNumericalData(dealIndex, 6),
      orderModel.getDealNumericalData(dealIndex, 5),
      orderModel.getDealNumericalData(dealIndex, 0),
      orderModel.getDealNumericalData(dealIndex, 7),
      orderModel.getDealNumericalData(dealIndex, 8),
      dealIndex
    );
  }

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

  function getDealIndex(uint i) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    return orderModel.getDealIndex(tx.origin, i);
  }

  function getDealGlobalItemIndex(uint i) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealNumericalData(dealIndex, 5);
  }

  function readFlag(uint i, uint8 flagIndex) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    // flagIndex < 11 --- flag index is out of bound.
    require(i < orderModel.getDealCount(tx.origin) && flagIndex < 11);

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealFlag(dealIndex, flagIndex);
  }

  function isDealSeller(uint i) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealRole(dealIndex, 1) == tx.origin;
  }

  function getDealSeller(uint i) external view returns (address)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealRole(dealIndex, 1);
  }

  function isDealBuyer(uint i) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealRole(dealIndex, 0) == tx.origin;
  }

  function getDealBuyer(uint i) external view returns (address)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealRole(dealIndex, 0);
  }

  function isDealAdmin(uint i) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return orderModel.getDealRole(dealIndex, 2) == tx.origin;
  }

  function isDealDisputePeriodExpired(uint i) external view returns (bool)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);
    return (block.number.sub(orderModel.getDealNumericalData(dealIndex, 1)) > orderModel.getDealNumericalData(dealIndex, 4));
  }

  function getDisputePeriodRemains(uint i) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);

    uint timeElapsed = block.number.sub(orderModel.getDealNumericalData(dealIndex, 1));
    if(timeElapsed < orderModel.getDealNumericalData(dealIndex, 4))
    {
      return orderModel.getDealNumericalData(dealIndex, 4).sub(timeElapsed);
    }

    return 0;
  }

  function getCancellationPeriodRemains(uint i) external view returns (uint)
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // i < dealOwners[tx.origin].length --- deal count is out of bound.
    require(i < orderModel.getDealCount(tx.origin));

    uint dealIndex = orderModel.getDealIndex(tx.origin, i);

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