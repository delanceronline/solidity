pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';

contract EventModel {
  
  address public modelAddress;

  modifier controllerOnly() {

    require(Model(modelAddress).isController(msg.sender), "Controller access only in event model");
    _;

  }
  
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in event model");
    _; 

  }

  event onPushMarketPGPPublicKey(string publicKey);  
  event onPushAnnouncement(uint indexed id, bytes title, bytes message);
  event onModifyAnnouncement(uint indexed id, uint8 operator, bytes details);
  event onAddItemDetails(uint indexed igi, uint id, bytes details);
  event onSetItemOfCategory(uint indexed category, uint indexed igi, bytes title, bool isEnabled);
  event onSetItemTag(uint indexed igi, bytes32 indexed lowerCaseHash, bytes32 indexed originalHash, bytes tag, bool isEnabled);
  event onAddDiscountToClient(address indexed vendor, address indexed client, uint indexed igi, uint8 discountRate, bytes additional);
  event onAddBatchOffer(uint indexed igi, bytes details);
  event onAddUserProfile(address indexed user, bytes32 indexed nickNameHash, bytes nickName, bytes about, string publicPGP, bytes additional);
  event onSetFeaturedItem(uint indexed igi, bool isEnabled);
  event onSetFeaturedVendor(address indexed vendor, bool isEnabled);
  event onSetFavourSeller(address indexed buyer, address indexed seller, bool isEnabled);
  event onSetFavourItem(address indexed buyer, uint indexed igi, bool isEnabled);
  event onMessageSent(address indexed sender, address indexed receiver, bytes details);

  event onDealCreated(uint indexed dealIndex, address indexed seller, address indexed buyer, string buyerNote);
  event onDealSetShippingNote(uint indexed dealIndex, string shippingNote);
  event onDealFinalized(address indexed seller, address indexed buyer, uint indexed itemGlobalIndex, uint dealIndex);
  event onDealRatedByBuyer(address indexed seller, uint indexed itemGlobalIndex, uint indexed dealIndex, address buyer, uint8 rating, bytes review);
  event onDealRatedBySeller(address indexed seller, uint indexed itemGlobalIndex, uint indexed dealIndex, address buyer, uint8 rating, bytes review);
  event onDisputeDeal(uint indexed dealIndex, string details);
  event onDisputeResolved(uint indexed dealIndex, bool shouldRefund, uint disputeHandlingFee);
  event onRateModerator(address indexed voter, address indexed moderator, uint indexed dealIndex, uint8 rating, bytes review);

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------
  // Emit events
  // ------------------------------------------------------------------------------------

  function onPushMarketPGPPublicKeyEmit(string calldata publicKey) controllerOnly external{

    emit onPushMarketPGPPublicKey(publicKey);

  }

  function onPushAnnouncementEmit(uint id, bytes calldata title, bytes calldata message) controllerOnly external{

    emit onPushAnnouncement(id, title, message);

  }

  function onModifyAnnouncementEmit(uint id, uint8 operator, bytes calldata details) controllerOnly external{

    emit onModifyAnnouncement(id, operator, details);

  }

  function onAddItemDetailsEmit(uint igi, uint id, bytes calldata details) controllerOnly external{

    emit onAddItemDetails(igi, id, details);

  }

  function onSetItemOfCategoryEmit(uint category, uint igi, bytes calldata title, bool isEnabled) controllerOnly external{

    emit onSetItemOfCategory(category, igi, title, isEnabled);

  }

  function onSetItemTagEmit(uint igi, bytes32 lowerCaseHash, bytes32 originalHash, bytes calldata tag, bool isEnabled) controllerOnly external{

    emit onSetItemTag(igi, lowerCaseHash, originalHash, tag, isEnabled);

  }

  function onAddDiscountToClientEmit(address vendor, address client, uint igi, uint8 discountRate, bytes calldata additional) controllerOnly external{

    emit onAddDiscountToClient(vendor, client, igi, discountRate, additional);

  }

  function onAddBatchOfferEmit(uint igi, bytes calldata details) controllerOnly external{

    emit onAddBatchOffer(igi, details);

  }

  function onAddUserProfileEmit(address user, bytes32 nickNameHash, bytes calldata nickName, bytes calldata about, string calldata publicPGP, bytes calldata additional) controllerOnly external{

    emit onAddUserProfile(user, nickNameHash, nickName, about, publicPGP, additional);

  }

  function onSetFeaturedItemEmit(uint igi, bool isEnabled) controllerOnly external{

    emit onSetFeaturedItem(igi, isEnabled);

  }

  function onSetFeaturedVendorEmit(address vendor, bool isEnabled) controllerOnly external{

    emit onSetFeaturedVendor(vendor, isEnabled);

  }

  function onSetFavourSellerEmit(address buyer, address seller, bool isEnabled) controllerOnly external{

    emit onSetFavourSeller(buyer, seller, isEnabled);

  }

  function onSetFavourItemEmit(address buyer, uint igi, bool isEnabled) controllerOnly external{

    emit onSetFavourItem(buyer, igi, isEnabled);

  }

  function onMessageSentEmit(address sender, address receiver, bytes calldata details) controllerOnly external{

    emit onMessageSent(sender, receiver, details);

  }

  function onDealCreatedEmit(uint dealIndex, address seller, address buyer, string calldata buyerNote) controllerOnly external{

    emit onDealCreated(dealIndex, seller, buyer, buyerNote);

  }

  function onDealSetShippingNoteEmit(uint dealIndex, string calldata shippingNote) controllerOnly external{

    emit onDealSetShippingNote(dealIndex, shippingNote);

  }

  function onDealFinalizedEmit(address seller, address buyer, uint itemGlobalIndex, uint dealIndex) controllerOnly external{

    emit onDealFinalized(seller, buyer, itemGlobalIndex, dealIndex);

  }

  function onDealRatedByBuyerEmit(address seller, uint itemGlobalIndex, uint dealIndex, address buyer, uint8 rating, bytes calldata review) controllerOnly external{

    emit onDealRatedByBuyer(seller, itemGlobalIndex, dealIndex, buyer, rating, review);

  }

  function onDealRatedBySellerEmit(address seller, uint itemGlobalIndex, uint dealIndex, address buyer, uint8 rating, bytes calldata review) controllerOnly external{

    emit onDealRatedBySeller(seller, itemGlobalIndex, dealIndex, buyer, rating, review);

  }

  function onDisputeDealEmit(uint dealIndex, string calldata details) controllerOnly external{

    emit onDisputeDeal(dealIndex, details);

  }

  function onDisputeResolvedEmit(uint dealIndex, bool shouldRefund, uint disputeHandlingFee) controllerOnly external{

    emit onDisputeResolved(dealIndex, shouldRefund, disputeHandlingFee);

  }

  function onRateModeratorEmit(address voter, address moderator, uint dealIndex, uint8 rating, bytes calldata review) controllerOnly external{

    emit onRateModerator(voter, moderator, dealIndex, rating, review);

  }

  // ------------------------------------------------------------------------------------

}