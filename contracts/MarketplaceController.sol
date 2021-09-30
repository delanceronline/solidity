pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductModel.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';

/*
------------------------------------------------------------------------------------

Main controller class of the entire marketplace. 
It mainly has access to the main model class in Model.sol which holds all important datum of the marketplace.

------------------------------------------------------------------------------------
*/

contract MarketplaceController {
  
  using SafeMath for uint256;

  address public modelAddress;
  uint public bornTime;

  // administrator only modifier
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in marketplace controller");
    _; 

  }

  // moderator only modifier
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

  // set event model class contract address
  function setEventModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setEventModelAddress(addr);
  }

  // set product / item model class contract address
  function setProductModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setProductModelAddress(addr);
  }

  // set order model class contract address
  function setOrderModelAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderModelAddress(addr);
  }

  // set marketplace controller address and this function is used for updating existing marketplace controller
  function setMarketplaceControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setMarketplaceControllerAddress(addr);
  }

  // set product / item controller class contract address
  function setProductControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setProductControllerAddress(addr);
  }

  // set order details controller class contract address
  function setOrderDetailsControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderDetailsControllerAddress(addr);
  }

  // set order management controller class contract address
  function setOrderManagementControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderManagementControllerAddress(addr);
  }

  // set order settlement controller class contract address
  function setOrderSettlementControllerAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderSettlementControllerAddress(addr);
  }  

  // set order escrow class contract address
  function setOrderEscrowAddress(address addr) adminOnly external
  {
    Model(modelAddress).setOrderEscrowAddress(addr);
  }

  // set public and existing pegged coin class contract address
  function setStableCoinAddress(address addr) adminOnly external
  {
    Model(modelAddress).setStableCoinAddress(addr);
  }

  // set DELA token class contract address
  function setTokenAddress(address addr) adminOnly external
  {
    Model(modelAddress).setTokenAddress(addr);
  }

  // set DELA token escrow class contract address
  function setTokenEscrowAddress(address addr) adminOnly external
  {
    Model(modelAddress).setTokenEscrowAddress(addr);
  }

  // set dividend pool class contract address
  function setDividendPoolAddress(address addr) adminOnly external
  {
    Model(modelAddress).setDividendPoolAddress(addr);
  }

  // ------------------------------------------------------------------------------------
  // Marketplace management
  // ------------------------------------------------------------------------------------

  // set marketplace's PGP public key
  function setMarketPublicPGP(string calldata publicPGP) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onPushMarketPGPPublicKeyEmit(publicPGP);
  }

  // add a new marketplace announcement
  function pushAnnouncement(uint id, bytes calldata title, bytes calldata message) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onPushAnnouncementEmit(id, title, message);
  }

  // update an existing announcement
  function modifyAnnouncement(uint id, uint8 operator, bytes calldata details) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onModifyAnnouncementEmit(id, operator, details);
  }

  // set an item as a featured one
  function setFeaturedItem(uint igi, bool isEnabled) adminOnly external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onSetFeaturedItemEmit(igi, isEnabled);
  }

  // set a merchant as a featured one
  function setFeaturedVendor(address vendor, bool isEnabled) adminOnly external
  {
    require(vendor != address(0));
    EventModel(Model(modelAddress).eventModelAddress()).onSetFeaturedVendorEmit(vendor, isEnabled);
  }

  // ban an existing seller / merchant by the admin
  function setSellerBanned(address seller, bool isBanned) adminOnly external
  {
    require(seller != address(0));
    Model(modelAddress).setSellerBanned(seller, isBanned);
  }

  // get the rate of marketplace's commission upon different turnover tiers
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

  // get the rate of moderator's handling fee rate upon different turnover tiers
  function calculateModeratorHandlingFeeRate(uint priceUSD) public view returns (uint)
  {
    Model model = Model(modelAddress);
    require(model.getModeratorHandlingFeeRatesLength() == model.getModeratorHandlingFeeBoundsLength(), 'model.getModeratorHandlingFeeRatesLength() != model.getModeratorHandlingFeeBoundsLength()');

    uint rate = model.getModeratorHandlingFeeRate(model.getModeratorHandlingFeeRatesLength() - 1);
    if(priceUSD <= model.getModeratorHandlingFeeBound(model.getModeratorHandlingFeeBoundsLength() - 1))
    {
      for(uint i = 1; i < model.getModeratorHandlingFeeBoundsLength(); i++)
      {
        if(priceUSD >= model.getModeratorHandlingFeeBound(i - 1) && priceUSD <= model.getModeratorHandlingFeeBound(i))
        {
          rate = model.getModeratorHandlingFeeRate(i - 1);
          break;
        }
      }
    }

    return rate;
  }  

  // ------------------------------------------------------------------------------------
  // User's account management
  // ------------------------------------------------------------------------------------

  // add an user profile
  function addProfile(bytes calldata nickName, bytes32 nickNameHash, bytes calldata about, string calldata publicPGP, bytes calldata additional) external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onAddUserProfileEmit(msg.sender, nickNameHash, nickName, about, publicPGP, additional);
  }

  // check if a seller is banned
  function isSellerBanned(address seller) view external returns (bool)
  {
    require(seller != address(0));

    return Model(modelAddress).isSellerBanned(seller);
  }

  // set a merchant as a favour one
  function setFavourSeller(address seller, bool isEnabled) external
  {
    require(seller != address(0));
    EventModel(Model(modelAddress).eventModelAddress()).onSetFavourSellerEmit(msg.sender, seller, isEnabled);
  }

  // send a pm to a user
  function sendMessage(address receiver, bytes calldata details) external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onMessageSentEmit(msg.sender, receiver, details);
  }

  // ------------------------------------------------------------------------------------
  // Marketplace setting
  // ------------------------------------------------------------------------------------

  // add a bound for a turnover tier of marketplace's commission
  function addMarketplaceCommissionBound(uint value) external adminOnly
  {
    Model(modelAddress).addMarketplaceCommissionBound(value);
  }

  // update a bound for a turnover tier of marketplace's commission
  function setMarketplaceCommissionBound(uint index, uint value) external adminOnly
  {
    Model(modelAddress).setMarketplaceCommissionBound(index, value);
  }

  // add the rate of a marketplace's commission tier
  function addMarketplaceCommissionRate(uint value) external adminOnly
  {
    Model(modelAddress).addMarketplaceCommissionRate(value);
  }

  // update the rate of a marketplace's commission tier
  function setMarketplaceCommissionRate(uint index, uint value) external adminOnly
  {
    Model(modelAddress).setMarketplaceCommissionRate(index, value);
  }

  // get the number of bounds from marketplace's commission turnover tiers
  function getMarketplaceCommissionBoundsLength() public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionBoundsLength();
  }

  // get the bound from marketplace's commission turnover tiers
  function getMarketplaceCommissionBound(uint index) public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionBound(index);
  }

  // get the number of rates from marketplace's commission turnover tiers
  function getMarketplaceCommissionRatesLength() public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionRatesLength();
  }

  // get the rate from marketplace's commission turnover tiers
  function getMarketplaceCommissionRate(uint index) public view returns (uint)
  {
    return Model(modelAddress).getMarketplaceCommissionRate(index);
  }

  // set the marketplace's commission rate of a specific merchant
  function setVendorCommissionRates(address sellerAddress, uint rate) external adminOnly
  {
    Model(modelAddress).setVendorCommissionRates(sellerAddress, rate);
  }

  // add an administrator
  function addAdmin(address addr) external adminOnly
  {
    Model(modelAddress).addAdmin(addr);
  }

  // get the number of administrators
  function getAdminCount() public view returns (uint)
  {
    return Model(modelAddress).getAdminCount();
  }

  // check if a user is an administrator
  function isAdmin(address addr) public view returns (bool)
  {
    return Model(modelAddress).isAdmin(addr);
  }

  // add a moderator
  function addModerator(address moderator) external adminOnly
  {
    return Model(modelAddress).addModerator(moderator);
  }

  // remove a moderator
  function removeModerator(address moderator) external adminOnly
  {
    Model(modelAddress).removeModerator(moderator);
  }

  // get the number of moderators
  function getModeratorCount() public view returns (uint)
  {
    return Model(modelAddress).getModeratorCount();
  }
  
  // check if a user is a moderator
  function isModerator(address addr) public view returns (bool)
  {
    return Model(modelAddress).isModerator(addr);
  }

  // set marketplace's contact
  function setMarketContact(bytes calldata contact) external adminOnly
  {
    return Model(modelAddress).saveMarketContact(contact);
  }

  // get marketplace's contact
  function getMarketContact() external view returns (bytes memory)
  {
    return Model(modelAddress).marketContact();
  }

  // set the contact for moderator group
  function setModerationContact(bytes calldata contact) external adminOnly
  {
    Model(modelAddress).setModerationContact(contact);
  }

  // get the contact of the moderator group
  function getModerationContact() external view returns (bytes memory)
  {
    return Model(modelAddress).moderationContact();
  }
}