pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './StableCoin.sol';

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
  
  address[] public customizedControllers;
  address[] public customizedModels;

  modifier controllerOnly()
  {
    require(isController(msg.sender), "Controller access only in main model");
    _;
  }

  modifier marketPlaceControllerOnly()
  {
    require(marketplaceControllerAddress == msg.sender, "Marketplace controller access only in main model");
    _;
  }

  modifier adminOnly()
  {
    require(isAdmin(msg.sender), "Admin access only in main model");
    _;
  }
  

  uint[] public marketplaceCommissionBounds;
  uint[] public marketplaceCommissionRates;

  bytes public moderationContact;
  bytes public marketContact;

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

  function setMarketplaceControllerAddressOnce(address addr) adminOnly external
  {
    require(marketplaceControllerAddress == address(0), "Admin is only allowed to set marketplace controller address once.");

    marketplaceControllerAddress = addr;
  }

  function setEventModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(eventModelAddress == address(0), "event model already set");

    eventModelAddress = addr;
  }

  function setProductModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(productModelAddress == address(0), "product model already set");

    productModelAddress = addr;
  }

  function setOrderModelAddress(address addr) marketPlaceControllerOnly external
  {
    require(orderModelAddress == address(0), "order model already set");

    orderModelAddress = addr;
  }

  function setOrderEscrowAddress(address addr) marketPlaceControllerOnly external
  {
    require(orderEscrowAddress == address(0), "order escrow already set");

    orderEscrowAddress = addr;
  }

  function setStableCoinAddress(address addr) marketPlaceControllerOnly external
  {
    require(stableCoinAddress == address(0), "stable coin already set");

    stableCoinAddress = addr;
  }

  function setTokenAddress(address addr) marketPlaceControllerOnly external
  {
    require(tokenAddress == address(0), "token already set");

    tokenAddress = addr;
  }

  function setTokenEscrowAddress(address addr) marketPlaceControllerOnly external
  {
    require(tokenEscrowAddress == address(0), "token escrow already set");

    tokenEscrowAddress = addr;
  }

  function setDividendPoolAddress(address addr) marketPlaceControllerOnly external
  {
    require(dividendPoolAddress == address(0), "dividend pool already set");

    dividendPoolAddress = addr;
  }

  function setMarketplaceControllerAddress(address addr) marketPlaceControllerOnly external
  {
    marketplaceControllerAddress = addr;
  }

  function setProductControllerAddress(address addr) marketPlaceControllerOnly external
  {
    productControllerAddress = addr;
  }

  function setOrderDetailsControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderDetailsControllerAddress = addr;
  }

  function setOrderManagementControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderManagementControllerAddress = addr;
  }

  function setOrderSettlementControllerAddress(address addr) marketPlaceControllerOnly external
  {
    orderSettlementControllerAddress = addr;
  }  

  function saveMarketContact(bytes calldata contact) controllerOnly external
  {
    marketContact = contact;
  }

  // ------------------------------------------------------------------------------------
  // Marketplace setting
  // ------------------------------------------------------------------------------------
  
  function setMarketplaceCommissionBound(uint index, uint value) controllerOnly public
  {
    require(index < marketplaceCommissionBounds.length);
    marketplaceCommissionBounds[index] = value;
  }

  function setMarketplaceCommissionRate(uint index, uint value) controllerOnly public
  {
    require(index < marketplaceCommissionRates.length);
    marketplaceCommissionRates[index] = value;
  }

  function addMarketplaceCommissionBound(uint value) controllerOnly public
  {
    marketplaceCommissionBounds.push(value);
  }

  function addMarketplaceCommissionRate(uint value) controllerOnly public
  {
    marketplaceCommissionRates.push(value);
  }

  function getMarketplaceCommissionBoundsLength() public view returns (uint)
  {
    return marketplaceCommissionBounds.length;
  }

  function getMarketplaceCommissionBound(uint index) public view returns (uint)
  {
    require(index < marketplaceCommissionBounds.length);

    return marketplaceCommissionBounds[index];
  }

  function getMarketplaceCommissionRatesLength() public view returns (uint)
  {
    return marketplaceCommissionRates.length;
  }

  function getMarketplaceCommissionRate(uint index) public view returns (uint)
  {
    require(index < marketplaceCommissionRates.length);

    return marketplaceCommissionRates[index];
  }

  function setModeratorHandlingFeeRate(uint rate) external controllerOnly
  {
    moderatorHandlingFeeRate = rate;
  }

  function setVendorCommissionRates(address sellerAddress, uint rate) external controllerOnly
  {
    require(sellerAddress != address(0));

    vendorCommissionRates[sellerAddress] = rate;
  }

  function saveModerationContact(bytes calldata contact) controllerOnly external
  {
    moderationContact = contact;
  }

  function getAdminCount() public view returns (uint)
  {
    return admins.length;
  }

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

  function addAdmin(address newAdmin) external controllerOnly
  {
    admins.push(newAdmin);
  }

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

  function addModerator(address moderator) external controllerOnly{

    require(moderator != address(0));

    moderators.push(moderator);

  }

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

  function getModeratorCount() public view returns (uint)
  {
    return moderators.length;
  }
  
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

  function addCustomizedController(address controller) external controllerOnly{

    require(controller != address(0));

    customizedControllers.push(controller);

  }

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

  function getCustomizedControllerCount() external view returns (uint)
  {
    return customizedControllers.length;
  }

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

  function addCustomizedModel(address model) external controllerOnly{

    require(model != address(0));

    customizedModels.push(model);

  }

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

  function getCustomizedModelCount() external view returns (uint)
  {
    return customizedModels.length;
  }

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

  function setSellerBanned(address seller, bool isBanned) controllerOnly external{

    require(seller != address(0));
    sellerBanList[seller] = isBanned;

  }

  function isSellerBanned(address seller) view external returns (bool)
  {
    require(seller != address(0));

    if(sellerBanList[seller])
      return true;
    else
      return false;
  }

  function getRefereeDealIndex(address referee, uint localIndex) external view returns (uint)
  {
    require(referee != address(0));
    require(localIndex < refereeDeals[referee].length);

    return refereeDeals[referee][localIndex];
  }

  function addRefereeDealIndex(address referee, uint dealIndex) external controllerOnly
  {
    require(referee != address(0));

    refereeDeals[referee].push(dealIndex);
  }

  function removeRefereeDealIndex(address referee, uint localIndex) external controllerOnly
  {
    require(localIndex < refereeDeals[referee].length);

    refereeDeals[referee][localIndex] = refereeDeals[referee][refereeDeals[referee].length - 1];
    refereeDeals[referee].length--;
  }
}