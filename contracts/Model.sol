pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './StableCoin.sol';

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

  address public stableCoinAddress;
  address public tokenAddress;
  address public tokenEscrowAddress;
  address public dividendPoolAddress;

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
  uint public moderatorHandlingFeeRate;

  constructor(address addr) public
  {
    admins.push(addr);

    // in %
    moderatorHandlingFeeRate = 4;

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

  // set public pegged stable coin (USD) contract address, once only
  function setStableCoinAddress(address addr) marketPlaceControllerOnly external
  {
    require(stableCoinAddress == address(0), "stable coin already set");
    stableCoinAddress = addr;
  }

  // set DELA token contract address, once only
  function setTokenAddress(address addr) marketPlaceControllerOnly external
  {
    require(tokenAddress == address(0), "token already set");
    tokenAddress = addr;
  }

  // set token escrow contract address, once only
  function setTokenEscrowAddress(address addr) marketPlaceControllerOnly external
  {
    require(tokenEscrowAddress == address(0), "token escrow already set");
    tokenEscrowAddress = addr;
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

  // ------------------------------------------------------------------------------------
  // Marketplace setting
  // ------------------------------------------------------------------------------------

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

  // set the rate for moderator's handling fee in resolving a dispute
  function setModeratorHandlingFeeRate(uint rate) external controllerOnly
  {
    moderatorHandlingFeeRate = rate;
  }

  // set the marketplace's commission rate of a specific merchant
  function setVendorCommissionRates(address sellerAddress, uint rate) external controllerOnly
  {
    require(sellerAddress != address(0));

    vendorCommissionRates[sellerAddress] = rate;
  }

  // set the contact for moderator group
  function saveModerationContact(bytes calldata contact) controllerOnly external
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
        delete admins[admins.length - 1];
        admins.length--;

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
        delete moderators[moderators.length - 1];
        moderators.length--;

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
        delete customizedControllers[customizedControllers.length - 1];
        customizedControllers.length--;

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
        delete customizedModels[customizedModels.length - 1];
        customizedModels.length--;

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
    refereeDeals[referee].length--;
  }
}