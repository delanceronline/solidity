// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './EventModel.sol';
import './SharedStructs.sol';

/*
------------------------------------------------------------------------------------

This is the model for the items / products which is only accessible by the product controller.

------------------------------------------------------------------------------------
*/

contract ProductModel {

  using SafeMath for uint256;

  address public modelAddress;

  // product controller only modifier
  modifier productControllerOnly()
  {
    require(msg.sender == Model(modelAddress).productControllerAddress(), "Product controller access only in product model");
    _;
  }

  // administrator only modiifer
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product model");
    _; 

  }

  // the item is only available to those who are inside the list, if it is non empty
  mapping (uint => mapping (address => bool)) public allowedClients;

  // item list
  SharedStructs.Item[] public listedItems;

  // store the global item indice of a vendor
  mapping (address => uint[]) public itemOwners;
  
  // store the item indice of a category
  mapping (uint8 => uint[]) public itemCategories;

  // store item details
  mapping (uint => bytes) public itemDetails;

  // item discounts for users
  mapping (uint => SharedStructs.ItemDiscount[]) public itemDiscounts;

  // batch purchase offers for items
  mapping (uint => bytes) public batchOffers;

  // hash tags for items
  mapping (bytes32 => SharedStructs.HashTag[]) public hashTags;

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------  

  function addHashTag(bytes32 lowerCaseHash, uint igi, bytes calldata tag, bool isEnabled) external productControllerOnly
  {
    SharedStructs.HashTag memory hashTag;
    hashTag.igi = igi;
    hashTag.tag = tag;
    hashTag.isEnabled = isEnabled;

    hashTags[lowerCaseHash].push(hashTag);
  }

  function enableTag(bytes32 lowerCaseHash, uint igi, bool isEnabled) external productControllerOnly
  {
    SharedStructs.HashTag[] storage tags = hashTags[lowerCaseHash];

    for(uint i = 0; i < tags.length; i++)
    {
      if(igi == tags[i].igi)
      {
        tags[i].isEnabled = isEnabled;
        break;
      }
    }
  }

  function addItemDiscount(uint igi, address client, uint8 discountRate, bytes calldata additional) external productControllerOnly
  {
    require(client != address(0));

    SharedStructs.ItemDiscount memory discount;
    discount.client = client;
    discount.discountRate = discountRate;
    discount.additional = additional;

    itemDiscounts[igi].push(discount);
  }

  function getItemDiscounts(uint igi) external view productControllerOnly returns (SharedStructs.ItemDiscount[] memory)
  {
    return itemDiscounts[igi];
  }

  function editItemDiscount(uint igi, address client, uint8 discountRate, bytes calldata additional) external productControllerOnly
  {
    require(client != address(0));

    SharedStructs.ItemDiscount[] storage discounts = itemDiscounts[igi];

    for(uint i = 0; i < discounts.length; i++)
    {
      if(client == discounts[i].client)
      {
        discounts[i].discountRate = discountRate;
        discounts[i].additional = additional;

        break;
      }
    }
  }

  function addBatchOffer(uint igi, bytes calldata details) external productControllerOnly
  {
    batchOffers[igi] = details;
  }

  function getBatchOffer(uint igi) external view productControllerOnly returns (bytes memory)
  {
    return batchOffers[igi];
  }

  function setBatchOffer(uint igi, bytes calldata details) external productControllerOnly
  {
    batchOffers[igi] = details;
  }

  function getAllItems() external view returns (SharedStructs.Item[] memory)
  {
    return listedItems;
  }

  function getItemIndices(address owner) external view returns (uint[] memory)
  {
    return itemOwners[owner];
  }

  function setItemDetail(uint igi, bytes calldata detail) external productControllerOnly
  {
    itemDetails[igi] = detail;
  }

  function getItemDetail(uint igi) external view productControllerOnly returns (bytes memory)
  {
    return itemDetails[igi];
  }

  // get the category index of am item
  function getItemCategory(uint globalItemIndex) external view returns (uint8)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].category;
  }

  // get the listed price in pegged USD of an item
  function getItemPriceUSD(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].priceUSD;
  }

  // check if an item is active
  function getItemIsActive(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isActive;
  }

  // get the title of an item
  function getItemTitle(uint globalItemIndex) external view returns (bytes memory)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].title;
  }

  // get the deal count of an item
  function getItemDealCount(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].dealCount;
  }

  // get the rating score of an item
  function getItemRatingScore(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].ratingScore;
  }

  // get the number of available items left of an item
  function getItemQuantityLeft(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].quantityLeft;
  }

  // check if quantity of an item is limited
  function getItemIsQuantityLimited(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isQuantityLimited;
  }

  // check if a deal of an item is private
  function getItemIsDealPrivate(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isDealPrivate;
  }

  // check if an item is banned
  function getItemIsBanned(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].isBanned;
  }

  // get the no dispute period of a deal in terms of the number of blocks
  function getItemNoDisputePeriod(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].noDisputePeriod;
  }

  // get the time limit for shipping by the seller
  function getItemShippingPeriod(uint globalItemIndex) external view returns (uint)
  {
    require(globalItemIndex < listedItems.length);

    return listedItems[globalItemIndex].shippingPeriod;
  }  

  // get the global item index of an item by providing a local index of a seller
  function getItemGlobalIndex(address owner, uint localIndex) external view returns (uint)
  {
    require(owner != address(0));
    require(localIndex < itemOwners[owner].length);

    return itemOwners[owner][localIndex];
  }

  // get the number of items in product model
  function getTotalItemCount() external view returns (uint)
  {
    return listedItems.length;
  }

  // get the number of items of a seller
  function getItemCount(address owner) external view returns (uint)
  {
    require(owner != address(0));

    return itemOwners[owner].length;
  }

  // check if an item is available for deal request
  function isBlockValid(uint globalItemIndex) external view returns (bool)
  {
    require(globalItemIndex < listedItems.length);

    if(block.number > listedItems[globalItemIndex].creationBlockNumber.add(listedItems[globalItemIndex].validBlockCount))
      return true;

    return false;
  }

  // set the number of blocks after that the item will be available for deal request since its creation block
  function setValidBlockCount(uint globalItemIndex, uint count) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].validBlockCount = count;
  }

  // add a new item to the list in product model
  function addItem(uint8 category, uint priceUSD, bytes calldata title, uint quantityLeft, bool isQuantityLimited, uint noDisputePeriod, uint shippingPeriod, uint validBlockCount) external productControllerOnly
  {
    //listedItems.push(SharedStructs.Item(category, priceUSD, true, title, '', 0, 0, quantityLeft, isQuantityLimited, false, false, noDisputePeriod, shippingPeriod, block.number, validBlockCount));
    
    SharedStructs.Item memory item;
    item.category = category;
    item.priceUSD = priceUSD;
    item.isActive = true;
    item.title = title;
    item.dealCount = 0;
    item.ratingScore = 0;
    item.quantityLeft = quantityLeft;
    item.isQuantityLimited = isQuantityLimited;
    item.isDealPrivate = false;
    item.isBanned = false;
    item.noDisputePeriod = noDisputePeriod;
    item.shippingPeriod = shippingPeriod;
    item.creationBlockNumber = block.number;
    item.validBlockCount = validBlockCount;
    listedItems.push(item);
    
  }

  // set item category index of an item
  function setItemCategory(uint globalItemIndex, uint8 category) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].category = category;
  }

  // set the listed price of an item in pegged USD
  function setItemPriceUSD(uint globalItemIndex, uint priceUSD) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].priceUSD = priceUSD;
  }

  // set the active flag of an item
  function setItemIsActive(uint globalItemIndex, bool isActive) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isActive = isActive;
  }

  // set the title of an item
  function setItemTitle(uint globalItemIndex, bytes calldata title) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].title = title;
  }

  // set the deal count of an item
  function setItemDealCount(uint globalItemIndex, uint dealCount) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].dealCount = dealCount;
  }

  // set the rating score of an item
  function setItemRatingScore(uint globalItemIndex, uint ratingScore) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].ratingScore = ratingScore;
  }

  // set the quantity left of an item
  function setItemQuantityLeft(uint globalItemIndex, uint quantityLeft) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].quantityLeft = quantityLeft;
  }

  // set if an item is limited in quantity
  function setItemIsQuantityLimited(uint globalItemIndex, bool isQuantityLimited) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isQuantityLimited = isQuantityLimited;
  }

  // set if an item only available for private deal
  function setItemIsDealPrivate(uint globalItemIndex, bool isDealPrivate) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isDealPrivate = isDealPrivate;
  }

  // set if an item is banned
  function setItemIsBanned(uint globalItemIndex, bool isBanned) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].isBanned = isBanned;
  }

  // set the no dispute period of an item in terms of the number of blocks
  function setItemNoDisputePeriod(uint globalItemIndex, uint noDisputePeriod) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].noDisputePeriod = noDisputePeriod;
  }

  // set the shipping time limit of an item in terms of the number of blocks
  function setItemShippingPeriod(uint globalItemIndex, uint shippingPeriod) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);

    listedItems[globalItemIndex].shippingPeriod = shippingPeriod;
  }  

  // add an allow buyer to an item
  function setItemAllowedClient(uint globalItemIndex, address clientAddress, bool isAllowed) external productControllerOnly
  {
    require(globalItemIndex < listedItems.length);
    require(clientAddress != address(0));

    //listedItems[globalItemIndex].allowedClients[clientAddress] = isAllowed;
    allowedClients[globalItemIndex][clientAddress] = isAllowed;
  }

  // check if a user is an allowed buyer of an item
  function getItemIsAllowedClient(uint globalItemIndex, address clientAddress) external view returns (bool)
  {
    require(clientAddress != address(0));
    require(globalItemIndex < listedItems.length);

    //return listedItems[globalItemIndex].allowedClients[clientAddress];
    return allowedClients[globalItemIndex][clientAddress];
  }

  // add the global item index of an item to an item seller / owner
  function addItemIndex(address seller, uint itemIndex) external productControllerOnly
  {
    require(seller != address(0));

    itemOwners[seller].push(itemIndex);
  }

  // remove the global item index of an item from an item seller / owner
  function removeItemIndex(address seller, uint position) external productControllerOnly
  {
    require(seller != address(0));
    require(position < itemOwners[seller].length);

    itemOwners[seller][position] = itemOwners[seller][itemOwners[seller].length.sub(1)];
    //itemOwners[seller].length--;
    itemOwners[seller].pop();
  }

  // add a global item index of an item to a category
  function addItemIndexToCategory(uint8 category, uint itemIndex) external productControllerOnly
  {
    itemCategories[category].push(itemIndex);
  }

  // remove a global item index of an item from a category
  function removeItemIndexFromCategory(uint8 category, uint position) external productControllerOnly
  {
    require(position < itemCategories[category].length);

    itemCategories[category][position] = itemCategories[category][itemCategories[category].length.sub(1)];
    itemCategories[category].pop();
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

    SharedStructs.Item storage item = listedItems[igi];
    require(item.category != 0);
    
    return (item.category, item.priceUSD, item.isActive, item.title, item.dealCount, item.ratingScore, item.quantityLeft, item.isQuantityLimited, item.creationBlockNumber, item.validBlockCount);
  }

  // increase the quantity left of an item
  function plusProductQuantity(uint igi, uint count) external productControllerOnly
  {
    SharedStructs.Item storage item = listedItems[igi];
    require(item.category != 0);

    item.quantityLeft = item.quantityLeft.add(count);
  }

  // decrease the quantity left of an item
  function minusProductQuantity(uint igi, uint count) external productControllerOnly
  {
    SharedStructs.Item storage item = listedItems[igi];
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