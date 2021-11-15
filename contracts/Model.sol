// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import "./StableCoin.sol";
import "./Token.sol";
import "./SharedStructs.sol";

/*
------------------------------------------------------------------------------------

Main model class of the entire marketplace. 
This class will never be updated once published to the mainnet.
All controllers have access to this class.

------------------------------------------------------------------------------------
*/

contract Model {

  using SafeMath for uint256;

  address[] public admins;
  address[] public moderators;

  address public marketplaceControllerAddress;
  address public productControllerAddress;
  address public orderDetailsControllerAddress;
  address public orderManagementControllerAddress;
  address public orderSettlementControllerAddress;

  address public orderEscrowAddress;
  address public dividendPoolAddress;

  address[] public stableCoinAddresses;
  address[] public tokenAddresses;
  address[] public tokenEscrowAddresses;

  address public eventModelAddress;
  address public productModelAddress;
  address public orderModelAddress;
    
  // reserved for future addons
  address[] public customizedControllers;
  address[] public customizedModels;

  // controller only modifier
  modifier controllerOnly()
  {
    require(isController(msg.sender), "Controller access only in main model");
    _;
  }

  // marketplace controller only modifier
  modifier marketPlaceControllerOnly()
  {
    require(marketplaceControllerAddress == msg.sender, "Marketplace controller access only in main model");
    _;
  }

  // administrator only modifier
  modifier adminOnly()
  {
    require(isAdmin(msg.sender), "Admin access only in main model");
    _;
  }
  
  // marketplace's commission turnover tier definitions
  uint[] public marketplaceCommissionBounds;
  uint[] public marketplaceCommissionRates;

  // marketplace and moderator contacts
  bytes public marketContact;
  bytes public moderationContact;

  // seller ban list
  mapping (address => bool) public sellerBanList;

  // store referee's deals
  mapping (address => uint[]) public refereeDeals;

  // store vendor's specified commission rate
  mapping (address => uint) public vendorCommissionRates;  

  // handling fee percentage for dispute handled by moderator
  uint[] public moderatorHandlingFeeBounds;
  uint[] public moderatorHandlingFeeRates;

  uint[] public featuredItemIndices;
  address[] public featuredVendors;

  mapping(address => address[]) public favourUsers;
  mapping(address => uint[]) public favourItems;

  uint[] public stableCoinDecimalDifferences;
  uint[] public stableCoinDecimalDifferencesPowered;

  string public marketPGPPublicKey;

  SharedStructs.Announcement[] public marketAnnouncements;
  mapping(address => SharedStructs.UserProfile) public userProfiles;
  mapping(address => SharedStructs.PrivateMessage[]) public privateMessages;

  constructor(address addr)
  {
    admins.push(addr);

    // in %
    moderatorHandlingFeeBounds.push(0);
    moderatorHandlingFeeBounds.push(300000000000000000000);
    moderatorHandlingFeeBounds.push(600000000000000000000);
    moderatorHandlingFeeBounds.push(900000000000000000000);

    moderatorHandlingFeeRates.push(4);
    moderatorHandlingFeeRates.push(3);
    moderatorHandlingFeeRates.push(2);
    moderatorHandlingFeeRates.push(1);


    // 4 commission tiers for different deal amount in USD, in wei unit
    marketplaceCommissionBounds.push(0);
    marketplaceCommissionBounds.push(200000000000000000000);
    marketplaceCommissionBounds.push(400000000000000000000);
    marketplaceCommissionBounds.push(800000000000000000000);

    // 4 commission rates, in %
    marketplaceCommissionRates.push(6);
    marketplaceCommissionRates.push(5);
    marketplaceCommissionRates.push(4);
    marketplaceCommissionRates.push(3);
  }

  // check if a class instance is a controller class
  function isController(address addr) view public returns (bool)
  {
    if(addr == marketplaceControllerAddress || addr == productControllerAddress || addr == orderDetailsControllerAddress || addr == orderManagementControllerAddress || addr == orderSettlementControllerAddress)
    {
      return true;
    }
    
    if(isCustomizedController(addr))
      return true;

    return false;
  }

  // check if a class instance is a model class
  function isModel(address addr) view external returns (bool)
  {
    if(addr == eventModelAddress || addr == productModelAddress || addr == orderModelAddress)
    {
      return true;
    }
    
    if(isCustomizedModel(addr))
      return true;

    return false;
  }


  // ------------------------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------------------------

  // this function is being called ONCE only during deployment for referencing marketplace controller contract address
  function setMarketplaceControllerAddressOnce(address addr) adminOnly external
  {
    require(marketplaceControllerAddress == address(0), "Admin is only allowed to set marketplace controller address once.");

    marketplaceControllerAddress = addr;
  }

  // set event model contract address, once only
  function setEventModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(eventModelAddress == address(0), "event model already set");
    eventModelAddress = addr;
  }

  // set product model contract address, once only
  function setProductModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(productModelAddress == address(0), "product model already set");
    productModelAddress = addr;
  }

  // set order model contract address, once only
  function setOrderModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(orderModelAddress == address(0), "order model already set");
    orderModelAddress = addr;
  }

  // set order escrow contract address, once only
  function setOrderEscrowAddress(address addr) marketPlaceControllerOnly external
  {
    require(orderEscrowAddress == address(0), "order escrow already set");
    orderEscrowAddress = addr;
  }

  // add public pegged stable coin contract address
  function addStableCoinAddress(address addr) marketPlaceControllerOnly external
  {
    //require(stableCoinAddress == address(0), "stable coin already set");
    //stableCoinAddress = addr;

    require(addr != address(0), 'addr is invalid');
    stableCoinAddresses.push(addr);

    uint stableCoinDecimalDifference = 18 - StableCoin(addr).decimals();
    stableCoinDecimalDifferences.push(stableCoinDecimalDifference);
    stableCoinDecimalDifferencesPowered.push(10 ** stableCoinDecimalDifference);
  }

  // add DELA token contract address
  function addTokenAddress(address addr) marketPlaceControllerOnly external
  {
    //require(tokenAddress == address(0), "token already set");
    //tokenAddress = addr;

    require(addr != address(0), 'addr is invalid');
    tokenAddresses.push(addr);
  }

  // add token escrow contract address
  function addTokenEscrowAddress(address addr) marketPlaceControllerOnly external
  {
    //require(tokenEscrowAddress == address(0), "token escrow already set");
    //tokenEscrowAddress = addr;

    require(addr != address(0), 'addr is invalid');
    tokenEscrowAddresses.push(addr);
  }

  // set dividend pool contract address, once only
  function setDividendPoolAddress(address addr) marketPlaceControllerOnly external
  {
    require(dividendPoolAddress == address(0), "dividend pool already set");
    dividendPoolAddress = addr;
  }

  // update marketplace's controller contract address
  function setMarketplaceControllerAddress(address addr) marketPlaceControllerOnly external
  {
    marketplaceControllerAddress = addr;
  }

  // update product controller contract address
  function setProductControllerAddress(address addr) marketPlaceControllerOnly external
  {
    productControllerAddress = addr;
  }

  // update order details controller contract address
  function setOrderDetailsControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderDetailsControllerAddress = addr;
  }

  // update order management controller contract address
  function setOrderManagementControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderManagementControllerAddress = addr;
  }

  // update order settlement controller contract address
  function setOrderSettlementControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderSettlementControllerAddress = addr;
  }  

  // set marketplace contact
  function saveMarketContact(bytes calldata contact) marketPlaceControllerOnly external
  {
    marketContact = contact;
  }

  function setMarketPGPPublicKey(string calldata key) marketPlaceControllerOnly external
  {
    marketPGPPublicKey = key;
  }

  // ------------------------------------------------------------------------------------
  // Marketplace setting
  // ------------------------------------------------------------------------------------

  function addPrivateMessage(address sender, address receiver, bytes calldata details) external marketPlaceControllerOnly
  {
    require(receiver != address(0));

    SharedStructs.PrivateMessage memory pm;
    pm.sender = sender;
    pm.details = details;
    pm.isRead = false;
    pm.blockNumber = block.number;

    privateMessages[receiver].push(pm);
  }

  function getPrivateMessages(address receiver) external view marketPlaceControllerOnly returns (SharedStructs.PrivateMessage[] memory)
  {
    require(receiver != address(0));

    return privateMessages[receiver];
  }

  function setPrivateMessageRead(address receiver, uint index, bool isRead) external marketPlaceControllerOnly
  {
    require(receiver != address(0));
    require(index < privateMessages[receiver].length, 'index is out of bound');

    SharedStructs.PrivateMessage storage message = privateMessages[receiver][index];
    message.isRead = isRead;
  }

  function addUserProfile(address user, bytes calldata nickName, bytes calldata about, string calldata publicOpenPGPKey, bytes calldata additional) external marketPlaceControllerOnly
  {
    require(user != address(0));

    SharedStructs.UserProfile memory userProfile;
    userProfile.nickName = nickName;
    userProfile.about = about;
    userProfile.publicOpenPGPKey = publicOpenPGPKey;
    userProfile.additional = additional;
    userProfile.blockNumber = block.number;

    userProfiles[user] = userProfile;
  }

  function getUserProfile(address user) external view marketPlaceControllerOnly returns (SharedStructs.UserProfile memory)
  {
    require(user != address(0));

    return userProfiles[user];
  }

  function editUserProfile(address user, bytes calldata nickName, bytes calldata about, string calldata publicOpenPGPKey, bytes calldata additional) external marketPlaceControllerOnly
  {
    require(user != address(0));

    SharedStructs.UserProfile storage userProfile = userProfiles[user];
    userProfile.nickName = nickName;
    userProfile.about = about;
    userProfile.publicOpenPGPKey = publicOpenPGPKey;
    userProfile.additional = additional;
  }

  function addMarketAnnouncement(bytes calldata title, bytes calldata message) external marketPlaceControllerOnly
  {
    SharedStructs.Announcement memory announcement;
    announcement.title = title;
    announcement.message = message;
    announcement.blockNumber = block.number;
    announcement.isEnabled = true;

    marketAnnouncements.push(announcement);
  }

  function editMarketAnnouncement(uint index, bytes calldata title, bytes calldata message, bool isEnabled) external marketPlaceControllerOnly
  {
    require(index < marketAnnouncements.length, 'index is out of bound');

    SharedStructs.Announcement storage announcement = marketAnnouncements[index];
    announcement.title = title;
    announcement.message = message;
    announcement.blockNumber = block.number;
    announcement.isEnabled = isEnabled;
  }

  function getMarketAnnouncements() external view marketPlaceControllerOnly returns (SharedStructs.Announcement[] memory)
  {
    return marketAnnouncements;
  }

  function addFavourItem(address owner, uint igi) external marketPlaceControllerOnly
  {
    require(owner != address(0));

    favourItems[owner].push(igi);
  }

  function removeFavourItem(address owner, uint igi) external marketPlaceControllerOnly
  {
    require(owner != address(0));

    for(uint i = 0; i < favourItems[owner].length; i++)
    {
      if(igi == favourItems[owner][i])
      {
        favourItems[owner][i] = favourItems[owner][favourItems[owner].length - 1];
        favourItems[owner].pop();

        break;
      }
    }
  }

  function getFavourItems(address owner) external view marketPlaceControllerOnly returns (uint[] memory)
  {
    require(owner != address(0));

    return favourItems[owner];
  }

  function addFavourUser(address owner, address user) external marketPlaceControllerOnly
  {
    require(owner != address(0));

    favourUsers[owner].push(user);
  }

  function removeFavourUser(address owner, address user) external marketPlaceControllerOnly
  {
    require(owner != address(0));

    for(uint i = 0; i < favourUsers[owner].length; i++)
    {
      if(user == favourUsers[owner][i])
      {
        favourUsers[owner][i] = favourUsers[owner][favourUsers[owner].length - 1];
        favourUsers[owner].pop();

        break;
      }
    }
  }

  function getFavourUsers(address owner) external view marketPlaceControllerOnly returns (address[] memory)
  {
    require(owner != address(0));

    return favourUsers[owner];
  }

  function addFeaturedItem(uint igi) external marketPlaceControllerOnly
  {
    featuredItemIndices.push(igi);
  }

  function removeFeaturedItem(uint igi) external marketPlaceControllerOnly
  {
    for(uint i = 0; i < featuredItemIndices.length; i++)
    {
      if(igi == featuredItemIndices[i])
      {
        featuredItemIndices[i] = featuredItemIndices[featuredItemIndices.length - 1];
        featuredItemIndices.pop();

        break;
      }
    }
  }

  function getFeaturedItemIndices() external view marketPlaceControllerOnly returns (uint[] memory)
  {
    return featuredItemIndices;
  }

  function addFeaturedVendor(address vendor) external marketPlaceControllerOnly
  {
    require(vendor != address(0));

    featuredVendors.push(vendor);
  }

  function removeFeaturedVendor(address vendor) external marketPlaceControllerOnly
  {
    require(vendor != address(0));

    for(uint i = 0; i < featuredVendors.length; i++)
    {
      if(vendor == featuredVendors[i])
      {
        featuredVendors[i] = featuredVendors[featuredVendors.length - 1];
        featuredVendors.pop();

        break;
      }
    }
  }

  function getFeaturedVendors() external view marketPlaceControllerOnly returns (address[] memory)
  {
    return featuredVendors;
  }

  // add a bound for a turnover tier of marketplace's commission
  function addMarketplaceCommissionBound(uint value) controllerOnly public
  {
    marketplaceCommissionBounds.push(value);
  }
  
  // update a bound for a turnover tier of marketplace's commission
  function setMarketplaceCommissionBound(uint index, uint value) controllerOnly public
  {
    require(index < marketplaceCommissionBounds.length);
    marketplaceCommissionBounds[index] = value;
  }

  // add the rate of a marketplace's commission tier
  function addMarketplaceCommissionRate(uint value) controllerOnly public
  {
    marketplaceCommissionRates.push(value);
  }

  // update the rate of a marketplace's commission tier
  function setMarketplaceCommissionRate(uint index, uint value) controllerOnly public
  {
    require(index < marketplaceCommissionRates.length);
    marketplaceCommissionRates[index] = value;
  }

  // get the number of bounds from marketplace's commission turnover tiers
  function getMarketplaceCommissionBoundsLength() public view returns (uint)
  {
    return marketplaceCommissionBounds.length;
  }

  // get the bound from marketplace's commission turnover tiers
  function getMarketplaceCommissionBound(uint index) public view returns (uint)
  {
    require(index < marketplaceCommissionBounds.length);

    return marketplaceCommissionBounds[index];
  }

  // get the number of rates from marketplace's commission turnover tiers
  function getMarketplaceCommissionRatesLength() public view returns (uint)
  {
    return marketplaceCommissionRates.length;
  }

  // get the rate from marketplace's commission turnover tiers
  function getMarketplaceCommissionRate(uint index) public view returns (uint)
  {
    require(index < marketplaceCommissionRates.length);

    return marketplaceCommissionRates[index];
  }

  // add a bound for a turnover tier of moderator's handling fee
  function addModeratorHandlingFeeBound(uint value) controllerOnly public
  {
    moderatorHandlingFeeBounds.push(value);
  }
  
  // update a bound for a turnover tier of moderator's handling fee
  function setModeratorHandlingFeeBound(uint index, uint value) controllerOnly public
  {
    require(index < moderatorHandlingFeeBounds.length);
    moderatorHandlingFeeBounds[index] = value;
  }

  // get the number of bounds from moderator's handling fee turnover tiers
  function getModeratorHandlingFeeBoundsLength() public view returns (uint)
  {
    return moderatorHandlingFeeBounds.length;
  }

  // get the bound from moderator's handling fee turnover tiers
  function getModeratorHandlingFeeBound(uint index) public view returns (uint)
  {
    require(index < moderatorHandlingFeeBounds.length);

    return moderatorHandlingFeeBounds[index];
  }

  // add the rate of a moderator's handling fee turnover tier
  function addModeratorHandlingFeeRate(uint value) controllerOnly public
  {
    moderatorHandlingFeeRates.push(value);
  }

  // update the rate of a moderator's handling fee
  function setModeratorHandlingFeeRate(uint index, uint value) controllerOnly public
  {
    require(index < moderatorHandlingFeeRates.length);
    moderatorHandlingFeeRates[index] = value;
  }

  // get the number of rates from moderator's handling fee turnover tiers
  function getModeratorHandlingFeeRatesLength() public view returns (uint)
  {
    return moderatorHandlingFeeRates.length;
  }

  // get the rate from marketplace's commission turnover tiers
  function getModeratorHandlingFeeRate(uint index) public view returns (uint)
  {
    require(index < moderatorHandlingFeeRates.length);

    return moderatorHandlingFeeRates[index];
  }

  // set the marketplace's commission rate of a specific merchant
  function setVendorCommissionRates(address sellerAddress, uint rate) external controllerOnly
  {
    require(sellerAddress != address(0));

    vendorCommissionRates[sellerAddress] = rate;
  }

  // set the contact for moderator group
  function setModerationContact(bytes calldata contact) controllerOnly external
  {
    moderationContact = contact;
  }

  // get the number of administrators
  function getAdminCount() public view returns (uint)
  {
    return admins.length;
  }

  // check if a user is an administrator
  function isAdmin(address addr) public view returns (bool)
  {
    for(uint i = 0; i < admins.length; i++)
    {
      if(addr == admins[i])
      {
        return true;
      }
    }

    return false;
  }

  // add an administrator
  function addAdmin(address newAdmin) external controllerOnly
  {
    admins.push(newAdmin);
  }

  // remove an administrator
  function removeAdmin(address payable oldAdmin) external controllerOnly
  {
    for(uint i = 0; i < admins.length; i++)
    {
      if(oldAdmin == admins[i])
      {
        admins[i] = admins[admins.length - 1];
        admins.pop();

        break;
      }
    }
  }

  // add a moderator
  function addModerator(address moderator) external controllerOnly{

    require(moderator != address(0));

    moderators.push(moderator);

  }

  // remove a moderator
  function removeModerator(address moderator) external controllerOnly{

    for(uint i = 0; i < moderators.length; i++)
    {
      if(moderators[i] == moderator)
      {
        moderators[i] = moderators[moderators.length - 1];
        moderators.pop();

        break;
      }
    }

  }

  // get the number of moderators
  function getModeratorCount() public view returns (uint)
  {
    return moderators.length;
  }
  
  // check if a user is a moderator
  function isModerator(address addr) public view returns (bool)
  {
    for(uint i = 0; i < moderators.length; i++)
    {
      if(addr == moderators[i])
      {
        return true;
      }
    }

    return false;
  }

  // add a customized controller instance
  function addCustomizedController(address controller) external controllerOnly{

    require(controller != address(0));

    customizedControllers.push(controller);

  }

  // remove a customized controller instance
  function removeCustomizedController(address controller) external controllerOnly{

    for(uint i = 0; i < customizedControllers.length; i++)
    {
      if(customizedControllers[i] == controller)
      {
        customizedControllers[i] = customizedControllers[customizedControllers.length - 1];
        //delete customizedControllers[customizedControllers.length - 1];
        //customizedControllers.length--;
        customizedControllers.pop();

        break;
      }
    }

  }

  // get the number of customized controllers
  function getCustomizedControllerCount() external view returns (uint)
  {
    return customizedControllers.length;
  }

  // check if a class instance is a customized controller
  function isCustomizedController(address controller) public view returns (bool)
  {
    for(uint i = 0; i < customizedControllers.length; i++)
    {
      if(controller == customizedControllers[i])
      {
        return true;
      }
    }

    return false;
  }

  // add a customized model instance
  function addCustomizedModel(address model) external controllerOnly{

    require(model != address(0));

    customizedModels.push(model);

  }

  // remove a customized model instance
  function removeCustomizedModel(address model) external controllerOnly{

    for(uint i = 0; i < customizedModels.length; i++)
    {
      if(customizedModels[i] == model)
      {
        customizedModels[i] = customizedModels[customizedModels.length - 1];
        customizedModels.pop();

        break;
      }
    }

  }

  // get the number of customized model instances
  function getCustomizedModelCount() external view returns (uint)
  {
    return customizedModels.length;
  }

  // check if an instance is a customized model class
  function isCustomizedModel(address model) public view returns (bool)
  {
    for(uint i = 0; i < customizedModels.length; i++)
    {
      if(model == customizedModels[i])
      {
        return true;
      }
    }

    return false;
  }

  // ban a specific merchant
  function setSellerBanned(address seller, bool isBanned) controllerOnly external{

    require(seller != address(0));
    sellerBanList[seller] = isBanned;

  }

  // check if a seller is banned
  function isSellerBanned(address seller) view external returns (bool)
  {
    require(seller != address(0));

    if(sellerBanList[seller])
      return true;
    else
      return false;
  }

  // get a deal's index of a referee
  function getRefereeDealIndex(address referee, uint localIndex) external view returns (uint)
  {
    require(referee != address(0));
    require(localIndex < refereeDeals[referee].length);

    return refereeDeals[referee][localIndex];
  }

  // add a deal's index to a referee
  function addRefereeDealIndex(address referee, uint dealIndex) external controllerOnly
  {
    require(referee != address(0));

    refereeDeals[referee].push(dealIndex);
  }

  // remove a deal's index from a referee
  function removeRefereeDealIndex(address referee, uint localIndex) external controllerOnly
  {
    require(localIndex < refereeDeals[referee].length);

    refereeDeals[referee][localIndex] = refereeDeals[referee][refereeDeals[referee].length - 1];
    refereeDeals[referee].pop();
  }
}