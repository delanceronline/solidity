pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductModel.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';

contract MarketplaceController {
  
  using SafeMath for uint256;

  address public modelAddress;
  uint public bornTime;


  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in marketplace controller");
    _; 

  }

  modifier moderatorOnly() {

    require(Model(modelAddress).isModerator(msg.sender), "Moderator access only in marketplace controller");
    _;

  }

  constructor(address addr) public
  {
    modelAddress = addr;
    bornTime = block.number; 
  }

  // ------------------------------------------------------------------------------------
  // Market initialization setters
  // ------------------------------------------------------------------------------------

  function setEventModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setEventModelAddress(addr);
  }

  function setProductModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setProductModelAddress(addr);
  }

  function setOrderModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderModelAddress(addr);
  }

  function setMarketplaceControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setMarketplaceControllerAddress(addr);
  }

  function setProductControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setProductControllerAddress(addr);
  }

  function setOrderDetailsControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderDetailsControllerAddress(addr);
  }

  function setOrderManagementControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderManagementControllerAddress(addr);
  }

  function setOrderSettlementControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderSettlementControllerAddress(addr);
  }  

  function setOrderEscrowAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderEscrowAddress(addr);
  }

  function setStableCoinAddress(address addr) adminOnly external
  {
    Model(modelAddress).setStableCoinAddress(addr);
  }

  function setTokenAddress(address addr) adminOnly external
  {
    Model(modelAddress).setTokenAddress(addr);
  }

  function setTokenEscrowAddress(address addr) adminOnly external
  {
    Model(modelAddress).setTokenEscrowAddress(addr);
  }

  function setDividendPoolAddress(address addr) adminOnly external
  {
    Model(modelAddress).setDividendPoolAddress(addr);
  }

  // ------------------------------------------------------------------------------------
  // Marketplace management
  // ------------------------------------------------------------------------------------

  function setMarketPublicPGP(string calldata publicPGP) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onPushMarketPGPPublicKeyEmit(publicPGP);
  }

  function pushAnnouncement(uint id, bytes calldata title, bytes calldata message) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onPushAnnouncementEmit(id, title, message);
  }

  function modifyAnnouncement(uint id, uint8 operator, bytes calldata details) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onModifyAnnouncementEmit(id, operator, details);
  }

  function setFeaturedItem(uint igi, bool isEnabled) adminOnly external{
    EventModel(Model(modelAddress).eventModelAddress()).onSetFeaturedItemEmit(igi, isEnabled);
  }

  function setFeaturedVendor(address vendor, bool isEnabled) adminOnly external{

    require(vendor != address(0));
    EventModel(Model(modelAddress).eventModelAddress()).onSetFeaturedVendorEmit(vendor, isEnabled);

  }

  function setSellerBanned(address seller, bool isBanned) adminOnly external{

    require(seller != address(0));

    Model(modelAddress).setSellerBanned(seller, isBanned);
  }

  function calculateMarketCommission(uint priceUSD) public view returns (uint)
  {
    Model model = Model(modelAddress);
    require(model.getMarketplaceCommissionRatesLength() == model.getMarketplaceCommissionBoundsLength());

    uint rate = model.getMarketplaceCommissionRate(model.getMarketplaceCommissionRatesLength() - 1);
    if(priceUSD <= model.getMarketplaceCommissionBound(model.getMarketplaceCommissionBoundsLength() - 1))
    {
      for(uint i = 1; i < model.getMarketplaceCommissionBoundsLength(); i++)
      {
        if(priceUSD >= model.getMarketplaceCommissionBound(i - 1) && priceUSD <= model.getMarketplaceCommissionBound(i))
        {
          rate = model.getMarketplaceCommissionRate(i - 1);
          break;
        }
      }
    }

    return rate;
  }

  // ------------------------------------------------------------------------------------
  // User's account management
  // ------------------------------------------------------------------------------------

  function addProfile(bytes calldata nickName, bytes32 nickNameHash, bytes calldata about, string calldata publicPGP, bytes calldata additional) external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onAddUserProfileEmit(msg.sender, nickNameHash, nickName, about, publicPGP, additional);
  }

  function isSellerBanned(address seller) view external returns (bool)
  {
    require(seller != address(0));

    return Model(modelAddress).isSellerBanned(seller);
  }

  function setFavourSeller(address seller, bool isEnabled) external
  {
    require(seller != address(0));
    EventModel(Model(modelAddress).eventModelAddress()).onSetFavourSellerEmit(msg.sender, seller, isEnabled);
  }

  function sendMessage(address receiver, bytes calldata details) external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onMessageSentEmit(msg.sender, receiver, details);
  }

  // ------------------------------------------------------------------------------------
  // Marketplace setting
  // ------------------------------------------------------------------------------------

  function setMarketplaceCommissionBound(uint index, uint value) external adminOnly
  {
    Model(modelAddress).setMarketplaceCommissionBound(index, value);
  }

  function setMarketplaceCommissionRate(uint index, uint value) external adminOnly
  {
    Model(modelAddress).setMarketplaceCommissionRate(index, value);
  }

  function addMarketplaceCommissionBound(uint value) external adminOnly
  {
    Model(modelAddress).addMarketplaceCommissionBound(value);
  }

  function addMarketplaceCommissionRate(uint value) external adminOnly
  {
    Model(modelAddress).addMarketplaceCommissionRate(value);
  }

  function getMarketplaceCommissionBoundsLength() public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionBoundsLength();
  }

  function getMarketplaceCommissionBound(uint index) public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionBound(index);
  }

  function getMarketplaceCommissionRatesLength() public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionRatesLength();
  }

  function getMarketplaceCommissionRate(uint index) public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionRate(index);
  }

  function setVendorCommissionRates(address sellerAddress, uint rate) external adminOnly
  {
    Model(modelAddress).setVendorCommissionRates(sellerAddress, rate);
  }

  function saveModerationContact(bytes calldata contact) external adminOnly
  {
    Model(modelAddress).saveModerationContact(contact);
  }

  function addAdmin(address addr) external adminOnly
  {
    Model(modelAddress).addAdmin(addr);
  }

  function getAdminCount() public view returns (uint)
  {
    return Model(modelAddress).getAdminCount();
  }

  function isAdmin(address addr) public view returns (bool)
  {
    return Model(modelAddress).isAdmin(addr);
  }

  function addModerator(address moderator) external adminOnly
  {
    return Model(modelAddress).addModerator(moderator);
  }

  function removeModerator(address moderator) external adminOnly
  {
    Model(modelAddress).removeModerator(moderator);
  }

  function getModeratorCount() public view returns (uint)
  {
    return Model(modelAddress).getModeratorCount();
  }
  
  function isModerator(address addr) public view returns (bool)
  {
    return Model(modelAddress).isModerator(addr);
  }   
  
  function getModerationContact() external view returns (bytes memory)
  {
    return Model(modelAddress).moderationContact();
  }

  function getMarketContact() external view returns (bytes memory)
  {
    return Model(modelAddress).marketContact();
  }  
}