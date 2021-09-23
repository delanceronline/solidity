pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductController.sol';
import './MarketplaceController.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';

/*
------------------------------------------------------------------------------------

This is the controller class for the order settlement (setup and finalization) which mainly gets access to the order model.

------------------------------------------------------------------------------------
*/

contract OrderSettlementController {
  
  using SafeMath for uint256;

  address public modelAddress;

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // called by seller only, to finalize a shipped deal after dispute period expired
  function finalizeDealWithoutDispute(uint localDealIndex) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    require(localDealIndex < orderModel.getTotalDealCount(), 'deal count is out of bound.');

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // !deal.flags[2] --- not finalized
    // msg.sender == deal.roles[1] --- Only seller should call this function after safe period.
    // block.number.sub(deal.numericalData[1]) > deal.numericalData[4] --- safe period expired
    // !deal.flags[5] || (deal.flags[6] && !deal.flags[7]) --- Not under dispute or resolved by moderator to sellerz favour
    require(!orderModel.getDealFlag(dealIndex, 2) && msg.sender == orderModel.getDealRole(dealIndex, 1) && block.number.sub(orderModel.getDealNumericalData(dealIndex, 1)) > orderModel.getDealNumericalData(dealIndex, 4) && (!orderModel.getDealFlag(dealIndex, 5) || (orderModel.getDealFlag(dealIndex, 6) && !orderModel.getDealFlag(dealIndex, 7))));
    
    orderModel.setDealFlag(dealIndex, 2, true);
    EventModel(Model(modelAddress).eventModelAddress()).onDealFinalizedEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 5), dealIndex);

    // increase completed deal count by 1
    ProductController(Model(modelAddress).productControllerAddress()).addItemDealCountByOne(orderModel.getDealNumericalData(dealIndex, 5));

    releaseFunds(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 2), orderModel.getDealNumericalData(dealIndex, 8), orderModel.getDealNumericalData(dealIndex, 7));
  }

  // called by buyer only, to finalize a shipped deal
  function finalizeDeal(uint localDealIndex, uint8 rating, bytes calldata review) external
  {
    OrderModel orderModel = OrderModel(Model(modelAddress).orderModelAddress());

    // deal count is out of bound AND rating score should be greater than zero.
    require(localDealIndex < orderModel.getTotalDealCount() && rating > 0);

    uint dealIndex = orderModel.getDealIndex(msg.sender, localDealIndex);

    // !deal.flags[2] && !deal.flags[5] && deal.flags[1] --- Not finalized AND not under dispute AND already shipped
    // tx.origin == deal.roles[0] --- Only buyer can finalize a deal within safe period.
    require(!orderModel.getDealFlag(dealIndex, 2) && !orderModel.getDealFlag(dealIndex, 5) && orderModel.getDealFlag(dealIndex, 1) && msg.sender == orderModel.getDealRole(dealIndex, 0));

    orderModel.setDealFlag(dealIndex, 2, true);
    EventModel(Model(modelAddress).eventModelAddress()).onDealFinalizedEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 5), dealIndex);

    // update deal rating and review
    orderModel.setDealFlag(dealIndex, 8, true);
    EventModel(Model(modelAddress).eventModelAddress()).onDealRatedByBuyerEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, orderModel.getDealRole(dealIndex, 0), rating, review);
    ProductController(Model(modelAddress).productControllerAddress()).addItemDealCountByOne(orderModel.getDealNumericalData(dealIndex, 5));
    ProductController(Model(modelAddress).productControllerAddress()).addItemRatingScore(orderModel.getDealNumericalData(dealIndex, 5), rating);

    releaseFunds(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 2), orderModel.getDealNumericalData(dealIndex, 8), orderModel.getDealNumericalData(dealIndex, 7));
  }

  // an internal function, to release funds to seller, referee (if any) and marketplace's dividend pool, during finalization
  function releaseFunds(address sellerAddress, address refereeAddress, uint dealMarketCommission, uint dealTotalAmount) internal
  {
    // pay the seller
    uint rate = Model(modelAddress).vendorCommissionRates(sellerAddress);
    if(rate == 0)
      rate = dealMarketCommission;
    
    // release fund to the seller
    uint net = dealTotalAmount.sub((dealTotalAmount.mul(rate)).div(100));
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(sellerAddress, net);
    
    // pool proportation
    uint tokenPoolAmount = dealTotalAmount.sub(net);

    // --------------------- rewarding DELA ---------------------
    Token delaToken = Token(Model(modelAddress).tokenAddress());
    uint rewardAmount = tokenPoolAmount;
    uint balanceLeft = delaToken.balanceOf(Model(modelAddress).tokenEscrowAddress());
    if(balanceLeft > 0)
    {
      if(tokenPoolAmount > balanceLeft)
      {
        // reward all remaining DELA in escrow
        rewardAmount = balanceLeft;
      }
    }

    uint refereeAmount = 0;
    // see if any referee
    if(refereeAddress != address(0))
    {
      refereeAmount = rewardAmount.div(2);
      TokenEscrow(Model(modelAddress).tokenEscrowAddress()).rewardToken(refereeAddress, refereeAmount);
    }

    // reward seller with DELA
    TokenEscrow(Model(modelAddress).tokenEscrowAddress()).rewardToken(sellerAddress, rewardAmount.sub(refereeAmount));
    // --------------------------------------------------------------- //

    // remaining to dividend pool
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(Model(modelAddress).dividendPoolAddress(), tokenPoolAmount);
  }

  // setup a deal, called by buyer only
  function setupDeal(address payable seller, uint igi, string calldata buyerNote, uint quantity, address referee, address moderator, uint totalUSD) external
  {
    ProductController productController = ProductController(Model(modelAddress).productControllerAddress());

    require(MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).isSellerBanned(seller) != true && !productController.isItemBanned(igi - 1), 'Seller or item is banned.');
    
    StableCoin stableCoin = StableCoin(Model(modelAddress).stableCoinAddress());
    require(productController.getItemPriceUSD(igi - 1) <= stableCoin.balanceOf(msg.sender), 'Not enough balance for paying.');

    addDeal(seller, igi, buyerNote, quantity, referee, moderator, totalUSD);

    stableCoin.transferFrom(msg.sender, Model(modelAddress).orderEscrowAddress(), totalUSD);
  }

  // an internal function, adding a deal to order model
  function addDeal(address seller, uint igi, string memory buyerNote, uint quantity, address referee, address moderator, uint totalUSD) internal
  {
    require(igi > 0, "Item global index is invalid.");
    require(ProductController(Model(modelAddress).productControllerAddress()).isProductBlockValid(igi.sub(1)), "Item is not available yet.");

    (, , bool isActive, , , , uint quantityLeft, bool isLimited, ,) = ProductController(Model(modelAddress).productControllerAddress()).getItemByGlobal(igi);

    // isActive --- Only active item can form a deal.
    // quantity <= quantityLeft || !isLimited --- Required quantity should not exceed the inventory.
    // !marketPlace.isPrivateDealItem(igi) || (marketPlace.isPrivateDealItem(igi) && marketPlace.isEligibleBuyer(igi, tx.origin)) --- Must be a public deal item or an eligible buyer for a private deal item.
    
    require(isActive && (quantity <= quantityLeft || !isLimited) && (!ProductController(Model(modelAddress).productControllerAddress()).isPrivateDealItem(igi) || (ProductController(Model(modelAddress).productControllerAddress()).isPrivateDealItem(igi) && ProductController(Model(modelAddress).productControllerAddress()).isEligibleBuyer(igi, tx.origin))));

    //OrderModel model = OrderModel(Model(modelAddress).orderModelAddress());
    uint dealIndex = OrderModel(Model(modelAddress).orderModelAddress()).createDeal();
    
    OrderModel(Model(modelAddress).orderModelAddress()).setDealRole(dealIndex, 0, tx.origin);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealRole(dealIndex, 1, seller);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealRole(dealIndex, 2, referee);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealRole(dealIndex, 3, moderator);

    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 0, block.number);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 3, ProductController(Model(modelAddress).productControllerAddress()).getNoDisputePeriodOfItem(igi));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 4, ProductController(Model(modelAddress).productControllerAddress()).getNoDisputePeriodOfItem(igi));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 5, igi);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 6, quantity);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 7, totalUSD);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 8, MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateMarketCommission(totalUSD));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 9, ProductController(Model(modelAddress).productControllerAddress()).getShippingPeriodOfItem(igi));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 10, Model(modelAddress).moderatorHandlingFeeRate());

    OrderModel(Model(modelAddress).orderModelAddress()).setDealFlag(dealIndex, 0, true);

    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(tx.origin, dealIndex);
    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(seller, dealIndex);

    ProductController(Model(modelAddress).productControllerAddress()).minusProductQuantity(igi, quantity);

    EventModel(Model(modelAddress).eventModelAddress()).onDealCreatedEmit(dealIndex, seller, tx.origin, buyerNote);    
  }

  // setup a direct deal (without deal dispute option), called by buyer
  function setupDirectDeal(address seller, uint igi, string calldata buyerNote, uint quantity, uint totalUSD) external
  {
    ProductController productController = ProductController(Model(modelAddress).productControllerAddress());

    require(MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).isSellerBanned(seller) && !productController.isItemBanned(igi - 1), 'Seller or item is banned.');

    StableCoin stableCoin = StableCoin(Model(modelAddress).stableCoinAddress());
    require(productController.getItemPriceUSD(igi - 1) <= stableCoin.balanceOf(msg.sender), 'Not enough balance for paying.');

    addDirectDeal(seller, igi, buyerNote, quantity, totalUSD);

    stableCoin.transferFrom(msg.sender, Model(modelAddress).orderEscrowAddress(), productController.getItemPriceUSD(igi - 1));
  }

  // an internal function to add a deal to order model
  function addDirectDeal(address seller, uint igi, string memory buyerNote, uint quantity, uint totalUSD) internal
  {
    require(igi > 0, "Item global index is invalid.");
    require(ProductController(Model(modelAddress).productControllerAddress()).isProductBlockValid(igi.sub(1)), "Item is not available yet.");

    (, , bool isActive, , , , uint quantityLeft, bool isLimited, ,) = ProductController(Model(modelAddress).productControllerAddress()).getItemByGlobal(igi);

    // isActive --- Only active item can form a deal.
    // quantity <= quantityLeft || !isLimited --- Required quantity should not exceed the inventory.
    // !DM(getMarketPlaceAddress()).isPrivateDealItem(igi) || (DM(getMarketPlaceAddress()).isPrivateDealItem(igi) && DM(getMarketPlaceAddress()).isEligibleBuyer(igi, tx.origin)) --- Must be a public deal item or an eligible buyer for a private deal item.
    require(isActive && (quantity <= quantityLeft || !isLimited) && (ProductController(Model(modelAddress).productControllerAddress()).isPrivateDealItem(igi) && ProductController(Model(modelAddress).productControllerAddress()).isEligibleBuyer(igi, tx.origin)));

    OrderModel model = OrderModel(Model(modelAddress).orderModelAddress());

    uint dealIndex = OrderModel(Model(modelAddress).orderModelAddress()).createDeal();

    model.setDealRole(dealIndex, 0, tx.origin);
    model.setDealRole(dealIndex, 1, seller);

    model.setDealNumericalData(dealIndex, 0, block.number);
    model.setDealNumericalData(dealIndex, 5, igi);
    model.setDealNumericalData(dealIndex, 6, quantity);
    model.setDealNumericalData(dealIndex, 7, totalUSD); // --- ???

    model.setDealFlag(dealIndex, 10, true);

    model.addDealIndex(tx.origin, dealIndex);
    model.addDealIndex(seller, dealIndex);

    ProductController(Model(modelAddress).productControllerAddress()).minusProductQuantity(igi, quantity);

    EventModel(Model(modelAddress).eventModelAddress()).onDealCreatedEmit(dealIndex, seller, tx.origin, buyerNote);
  }
  
}