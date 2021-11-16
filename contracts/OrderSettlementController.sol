// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

  constructor(address addr)
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

    uint coinIndex = orderModel.getDealNumericalData(dealIndex, 11);
    releaseFunds(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 2), orderModel.getDealNumericalData(dealIndex, 8), orderModel.getDealNumericalData(dealIndex, 7), coinIndex);
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
    orderModel.addDealVote(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 0), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, rating, review);

    EventModel(Model(modelAddress).eventModelAddress()).onDealRatedByBuyerEmit(orderModel.getDealRole(dealIndex, 1), orderModel.getDealNumericalData(dealIndex, 5), dealIndex, orderModel.getDealRole(dealIndex, 0), rating, review);
    ProductController(Model(modelAddress).productControllerAddress()).addItemDealCountByOne(orderModel.getDealNumericalData(dealIndex, 5));
    ProductController(Model(modelAddress).productControllerAddress()).addItemRatingScore(orderModel.getDealNumericalData(dealIndex, 5), rating);

    uint coinIndex = orderModel.getDealNumericalData(dealIndex, 11);
    releaseFunds(orderModel.getDealRole(dealIndex, 1), orderModel.getDealRole(dealIndex, 2), orderModel.getDealNumericalData(dealIndex, 8), orderModel.getDealNumericalData(dealIndex, 7), coinIndex);
  }

  // an internal function, to release funds to seller, referee (if any) and marketplace's dividend pool, during finalization
  function releaseFunds(address sellerAddress, address refereeAddress, uint dealMarketCommission, uint dealTotalAmountInWei, uint coinIndex) internal
  {
    Token delaToken = Token(Model(modelAddress).tokenAddresses(coinIndex));
    //StableCoin stableCoin = StableCoin(Model(modelAddress).stableCoinAddresses(coinIndex));

    //uint decimalFactor = 10 ** uint(delaToken.decimals() - stableCoin.decimals());
    uint decimalFactor = Model(modelAddress).stableCoinDecimalDifferencesPowered(coinIndex);
    uint dealTotalAmountInXwei = dealTotalAmountInWei.div(decimalFactor);

    // pay the seller
    uint rate = Model(modelAddress).vendorCommissionRates(sellerAddress);
    if(rate == 0)
      rate = dealMarketCommission;
    
    // release fund to the seller
    uint netInXwei = dealTotalAmountInXwei.sub((dealTotalAmountInXwei.mul(rate)).div(100));
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(sellerAddress, netInXwei, coinIndex);
    
    // pool proportation
    uint tokenPoolAmountInXwei = dealTotalAmountInXwei.sub(netInXwei);

    // remaining to dividend pool
    OrderEscrow(Model(modelAddress).orderEscrowAddress()).transferStabeCoin(Model(modelAddress).dividendPoolAddress(), tokenPoolAmountInXwei, coinIndex);

    // --------------------- rewarding DELA ---------------------    
    uint rewardAmountInWei = tokenPoolAmountInXwei.mul(decimalFactor);
    uint balanceLeftInWei = delaToken.balanceOf(Model(modelAddress).tokenEscrowAddresses(coinIndex));
    if(balanceLeftInWei > 0)
    {
      if(tokenPoolAmountInXwei.mul(decimalFactor) > balanceLeftInWei)
      {
        // reward all remaining DELA in escrow
        rewardAmountInWei = balanceLeftInWei;
      }
    }

    uint refereeAmountInWei = 0;
    // see if any referee
    if(refereeAddress != address(0))
    {
      refereeAmountInWei = rewardAmountInWei.div(2);
      TokenEscrow(Model(modelAddress).tokenEscrowAddresses(coinIndex)).rewardToken(refereeAddress, refereeAmountInWei);
    }

    // reward seller with DELA
    TokenEscrow(Model(modelAddress).tokenEscrowAddresses(coinIndex)).rewardToken(sellerAddress, rewardAmountInWei.sub(refereeAmountInWei));
    // --------------------------------------------------------------- //
  }
  
  // setup a deal, called by buyer only
  function setupDeal(address seller, uint igi, string calldata buyerNote, uint quantity, address referee, address moderator, uint totalUSDInWei, uint coinIndex) external
  {
    ProductController productController = ProductController(Model(modelAddress).productControllerAddress());

    require(MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).isSellerBanned(seller) != true && !productController.isItemBanned(igi - 1), 'Seller or item is banned.');
    
    StableCoin stableCoin = StableCoin(Model(modelAddress).stableCoinAddresses(coinIndex));

    require(totalUSDInWei <= stableCoin.balanceOf(msg.sender).mul(Model(modelAddress).stableCoinDecimalDifferencesPowered(coinIndex)), 'Not enough balance for paying.');
    
    SharedStructs.Deal memory deal;
    deal.roles[0] = tx.origin;
    deal.roles[1] = seller;
    deal.roles[2] = referee;
    deal.roles[3] = moderator;
    deal.numericalData[0] = block.number;
    deal.numericalData[3] = ProductController(Model(modelAddress).productControllerAddress()).getNoDisputePeriodOfItem(igi);
    deal.numericalData[4] = ProductController(Model(modelAddress).productControllerAddress()).getNoDisputePeriodOfItem(igi);
    deal.numericalData[5] = igi;
    deal.numericalData[6] = quantity;
    deal.numericalData[7] = totalUSDInWei;
    deal.numericalData[8] = MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateMarketCommission(totalUSDInWei);
    deal.numericalData[9] = ProductController(Model(modelAddress).productControllerAddress()).getShippingPeriodOfItem(igi);
    deal.numericalData[10] = MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateModeratorHandlingFeeRate(totalUSDInWei);
    deal.numericalData[11] = coinIndex;
    deal.flags[0] = true;
    deal.buyerNote = buyerNote;
    uint dealIndex = OrderModel(Model(modelAddress).orderModelAddress()).addDeal(deal);

    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(tx.origin, dealIndex);
    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(seller, dealIndex);

    ProductController(Model(modelAddress).productControllerAddress()).minusProductQuantity(igi, quantity);
    EventModel(Model(modelAddress).eventModelAddress()).onDealCreatedEmit(dealIndex, seller, tx.origin, buyerNote);   

    stableCoin.transferFrom(msg.sender, Model(modelAddress).orderEscrowAddress(), totalUSDInWei.div(Model(modelAddress).stableCoinDecimalDifferencesPowered(coinIndex)));
  }

  /*
  // an internal function, adding a deal to order model
  function addDeal(address seller, uint igi, string memory buyerNote, uint quantity, address referee, address moderator, uint totalUSDInWei) internal
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
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 7, totalUSDInWei);
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 8, MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateMarketCommission(totalUSDInWei));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 9, ProductController(Model(modelAddress).productControllerAddress()).getShippingPeriodOfItem(igi));
    OrderModel(Model(modelAddress).orderModelAddress()).setDealNumericalData(dealIndex, 10, MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).calculateModeratorHandlingFeeRate(totalUSDInWei));

    OrderModel(Model(modelAddress).orderModelAddress()).setDealFlag(dealIndex, 0, true);

    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(tx.origin, dealIndex);
    OrderModel(Model(modelAddress).orderModelAddress()).addDealIndex(seller, dealIndex);

    ProductController(Model(modelAddress).productControllerAddress()).minusProductQuantity(igi, quantity);

    EventModel(Model(modelAddress).eventModelAddress()).onDealCreatedEmit(dealIndex, seller, tx.origin, buyerNote);    
  }

  // setup a direct deal (without deal dispute option), called by buyer
  function setupDirectDeal(address seller, uint igi, string calldata buyerNote, uint quantity, uint totalUSDInWei, uint coinIndex) external
  {
    ProductController productController = ProductController(Model(modelAddress).productControllerAddress());

    require(MarketplaceController(Model(modelAddress).marketplaceControllerAddress()).isSellerBanned(seller) && !productController.isItemBanned(igi - 1), 'Seller or item is banned.');

    StableCoin stableCoin = StableCoin(Model(modelAddress).stableCoinAddresses(coinIndex));
    Token delaToken = Token(Model(modelAddress).tokenAddresses(coinIndex));

    //uint decimalFactor = 10 ** uint(delaToken.decimals() - stableCoin.decimals());
    uint decimalFactor = Model(modelAddress).staleCoinDecimalDifferencesPowered(coinIndex);
    require(totalUSDInWei <= stableCoin.balanceOf(msg.sender).mul(decimalFactor), 'Not enough balance for paying.');

    addDirectDeal(seller, igi, buyerNote, quantity, totalUSDInWei);

    stableCoin.transferFrom(msg.sender, Model(modelAddress).orderEscrowAddress(), totalUSDInWei.div(decimalFactor));
  }

  // an internal function to add a deal to order model
  function addDirectDeal(address seller, uint igi, string memory buyerNote, uint quantity, uint totalUSDInWei) internal
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
    model.setDealNumericalData(dealIndex, 7, totalUSDInWei); // --- ???

    model.setDealFlag(dealIndex, 10, true);

    model.addDealIndex(tx.origin, dealIndex);
    model.addDealIndex(seller, dealIndex);

    ProductController(Model(modelAddress).productControllerAddress()).minusProductQuantity(igi, quantity);

    EventModel(Model(modelAddress).eventModelAddress()).onDealCreatedEmit(dealIndex, seller, tx.origin, buyerNote);
  }
  */
}