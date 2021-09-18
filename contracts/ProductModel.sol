pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './EventModel.sol';

contract ProductModel {

  using SafeMath for uint256;

  address public modelAddress;

  /*
  modifier controllerOnly() {

    if(Model(modelAddress).isController(msg.sender)) _;

  }
  */

  modifier productControllerOnly()
  {
    require(msg.sender == Model(modelAddress).productControllerAddress(), "Product controller access only in product model");
    _;
  }

  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product model");
    _; 

  }

  struct Item
  {
    uint8 category;
    uint priceUSD;
    bool isActive;
    bytes title;
    uint dealCount;
    uint ratingScore;
    uint quantityLeft;
    bool isQuantityLimited;
    bool isDealPrivate;
    bool isBanned;
    uint noDisputePeriod;
    uint shippingPeriod;
    uint creationBlockNumber;
    uint validBlockCount;
    mapping (address => bool) allowedClients;
  }

  Item[] public listedItems;

  // store the global item indice of a vendor
  mapping (address => uint[]) public itemOwners;
  
  // store the item indice of a category
  mapping (uint8 => uint[]) public itemCategories;


  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------

  function getItemCategory(uint globalItemIndex) external view returns (uint8)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].category;
  }

  function getItemPriceUSD(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].priceUSD;
  }

  function getItemIsActive(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isActive;
  }

  function getItemTitle(uint globalItemIndex) external view returns (bytes memory)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].title;
  }

  function getItemDealCount(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].dealCount;
  }

  function getItemRatingScore(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].ratingScore;
  }

  function getItemQuantityLeft(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].quantityLeft;
  }

  function getItemIsQuantityLimited(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isQuantityLimited;
  }

  function getItemIsDealPrivate(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isDealPrivate;
  }

  function getItemIsBanned(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isBanned;
  }

  function getItemNoDisputePeriod(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].noDisputePeriod;
  }

  function getItemShippingPeriod(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].shippingPeriod;
  }  

  function getItemGlobalIndex(address owner, uint localIndex) external view returns (uint)
  {
    require(owner != address(0));
    require(localIndex < itemOwners[owner].length);

    return itemOwners[owner][localIndex];
  }

  function getTotalItemCount() external view returns (uint)
  {
    return listedItems.length;
  }

  function getItemCount(address owner) external view returns (uint)
  {
    require(owner != address(0));

    return itemOwners[owner].length;
  }

  function isBlockValid(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    if(block.number > listedItems[globalItemIndex].creationBlockNumber.add(listedItems[globalItemIndex].validBlockCount))
      return true;

    return false;
  }

  function setValidBlockCount(uint globalItemIndex, uint count) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].validBlockCount = count;
  }

  function addItem(uint8 category, uint priceUSD, bytes calldata title, uint quantityLeft, bool isQuantityLimited, uint noDisputePeriod, uint shippingPeriod, uint validBlockCount) external productControllerOnly
  {
    listedItems.push(Item(category, priceUSD, true, title, 0, 0, quantityLeft, isQuantityLimited, false, false, noDisputePeriod, shippingPeriod, block.number, validBlockCount));
  }

  function setItemCategory(uint globalItemIndex, uint8 category) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].category = category;
  }

  function setItemPriceUSD(uint globalItemIndex, uint priceUSD) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].priceUSD = priceUSD;
  }

  function setItemIsActive(uint globalItemIndex, bool isActive) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isActive = isActive;
  }

  function setItemTitle(uint globalItemIndex, bytes calldata title) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].title = title;
  }

  function setItemDealCount(uint globalItemIndex, uint dealCount) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].dealCount = dealCount;
  }

  function setItemRatingScore(uint globalItemIndex, uint ratingScore) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].ratingScore = ratingScore;
  }

  function setItemQuantityLeft(uint globalItemIndex, uint quantityLeft) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].quantityLeft = quantityLeft;
  }

  function setItemIsQuantityLimited(uint globalItemIndex, bool isQuantityLimited) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isQuantityLimited = isQuantityLimited;
  }

  function setItemIsDealPrivate(uint globalItemIndex, bool isDealPrivate) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isDealPrivate = isDealPrivate;
  }

  function setItemIsBanned(uint globalItemIndex, bool isBanned) external productControllerOnly
  {
    /*
    require(listedItems[igi].category > 0);
    listedItems[igi].isBanned = isBanned;
    */

    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isBanned = isBanned;
  }

  function setItemNoDisputePeriod(uint globalItemIndex, uint noDisputePeriod) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].noDisputePeriod = noDisputePeriod;
  }

  function setItemShippingPeriod(uint globalItemIndex, uint shippingPeriod) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].shippingPeriod = shippingPeriod;
  }  

  function setItemAllowedClient(uint globalItemIndex, address clientAddress, bool isAllowed) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);
    require(clientAddress != address(0));

    listedItems[globalItemIndex].allowedClients[clientAddress] = isAllowed;
  }

  function getItemIsAllowedClient(uint globalItemIndex, address clientAddress) external view returns (bool)
  {
    require(clientAddress != address(0));
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].allowedClients[clientAddress];
  }

  function addItemIndex(address seller, uint itemIndex) external productControllerOnly
  {
    require(seller != address(0));

    itemOwners[seller].push(itemIndex);
  }

  function removeItemIndex(address seller, uint position) external productControllerOnly
  {
    require(seller != address(0));
    require(position < itemOwners[seller].length);

    itemOwners[seller][position] = itemOwners[seller][itemOwners[seller].length.sub(1)];
    itemOwners[seller].length--;
  }

  function addItemIndexToCategory(uint8 category, uint itemIndex) external productControllerOnly
  {
    itemCategories[category].push(itemIndex);
  }

  function removeItemIndexFromCategory(uint8 category, uint position) external productControllerOnly
  {
    require(position < itemCategories[category].length);

    itemCategories[category][position] = itemCategories[category][itemCategories[category].length.sub(1)];
    itemCategories[category].length--;
  }

  // return num of items of a category
  function numOfItemsOfCategory(uint8 category) external view returns (uint)
  {
    return itemCategories[category].length;
  }

  // return the item details from a vendor, by given a local index
  function getItemByVendor(address vendor, uint localItemIndex) external view returns (uint8, uint, bool, bytes memory, uint, uint, uint, bool, uint){

    require(localItemIndex < itemOwners[vendor].length);

    uint ii = itemOwners[vendor][localItemIndex].sub(1);
    return (listedItems[ii].category, listedItems[ii].priceUSD, listedItems[ii].isActive, listedItems[ii].title, listedItems[ii].dealCount, listedItems[ii].ratingScore, listedItems[ii].quantityLeft, listedItems[ii].isQuantityLimited, ii + 1);
  }

  // get an item by given a global item index
  function getItemByGlobalIndex(uint igi) public view returns (uint8, uint, bool, bytes memory, uint, uint, uint, bool, uint, uint){

    Item memory item = listedItems[igi];
    require(item.category != 0);
    
    return (item.category, item.priceUSD, item.isActive, item.title, item.dealCount, item.ratingScore, item.quantityLeft, item.isQuantityLimited, item.creationBlockNumber, item.validBlockCount);
  }

  function plusProductQuantity(uint igi, uint count) external productControllerOnly
  {
    Item storage item = listedItems[igi];
    require(item.category != 0);

    item.quantityLeft = item.quantityLeft.add(count);
  }

  function minusProductQuantity(uint igi, uint count) external productControllerOnly
  {
    Item storage item = listedItems[igi];
    require(item.category != 0);

    if(item.quantityLeft < count)
    {
      item.quantityLeft = 0;
    }
    else
    {
      item.quantityLeft = item.quantityLeft.sub(count);
    }
  }
}