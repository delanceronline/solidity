// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductModel.sol';
import './SharedStructs.sol';

/*
------------------------------------------------------------------------------------

This is the controller class for the items / products which mainly gets access to the product model.

------------------------------------------------------------------------------------
*/

contract ProductController {
  
  using SafeMath for uint256;

  address public modelAddress;

  // administrator only modifier
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product controller");
    _; 

  }

  // moderator only modifier
  modifier moderatorOnly() {

    require(Model(modelAddress).isModerator(msg.sender), "Moderator access only in product controller");
    _;

  }

  // controller only modifier
  modifier controllerOnly(){

    require(Model(modelAddress).isController(msg.sender), "Controller access only in product controller");
    _;

  }

  constructor(address addr)
  {
    modelAddress = addr;
  }
  

  function getAllItems() external view returns (SharedStructs.Item[] memory)
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    return model.getAllItems();
  }

  function getItemIndices(address owner) external view returns (uint[] memory)
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    return model.getItemIndices(owner);
  }

  // ------------------------------------------------------------------------------------
  // User setting
  // ------------------------------------------------------------------------------------
  
  function addGlobalDiscount(address client, uint8 discountRate, bytes calldata additional) external
  {
    require(client != address(0));

    ProductModel(Model(modelAddress).productModelAddress()).addGlobalDiscount(msg.sender, client, discountRate, additional);
  }

  function getGlobalDiscounts(address seller) external view returns (SharedStructs.ItemDiscount[] memory)
  {
    require(seller != address(0));

    return ProductModel(Model(modelAddress).productModelAddress()).getGlobalDiscounts(seller);
  }
  
  function getGlobalDiscount(address seller, address buyer) external view returns (SharedStructs.ItemDiscount memory)
  {
    SharedStructs.ItemDiscount[] memory discounts = ProductModel(Model(modelAddress).productModelAddress()).getGlobalDiscounts(seller);
    for(uint i = 0; i < discounts.length; i++)
    {
      if(buyer == discounts[i].client)
        return discounts[i];
    }

    return SharedStructs.ItemDiscount(address(0), 0, '0x00', 0);
  }

  function editGlobalDiscount(address client, uint8 discountRate, bytes calldata additional) external
  {
    require(client != address(0));

    ProductModel(Model(modelAddress).productModelAddress()).editGlobalDiscount(msg.sender, client, discountRate, additional);
  }
  
  // add a discount offer for a buyer to a specific item
  function addClientDiscount(address client, uint localItemIndex, uint8 discountRate, bytes calldata details) external
  {
    require(client != address(0));

    uint igi = ProductModel(Model(modelAddress).productModelAddress()).getItemGlobalIndex(msg.sender, localItemIndex);

    if(!ProductModel(Model(modelAddress).productModelAddress()).doesItemDiscountExist(igi, client))
    {
      ProductModel(Model(modelAddress).productModelAddress()).addItemDiscount(igi, client, discountRate, details);
      EventModel(Model(modelAddress).eventModelAddress()).onAddDiscountToClientEmit(msg.sender, client, igi, discountRate, details);    
    }
  }

  function getProductDiscountsToClients(uint igi) external view returns (SharedStructs.ItemDiscount[] memory)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemDiscounts(igi);
  }

  function getClientDiscount(address client, uint igi) external view returns (SharedStructs.ItemDiscount memory)
  {
    SharedStructs.ItemDiscount[] memory discounts = ProductModel(Model(modelAddress).productModelAddress()).getItemDiscounts(igi);
    for(uint i = 0; i < discounts.length; i++)
    {
      if(discounts[i].client == client)
      {
        return discounts[i];
      }
    }

    return SharedStructs.ItemDiscount(address(0), 0, '', 0);
  }

  // add a batch purchase offer to an item
  function addBatchOffer(uint localItemIndex, bytes calldata details) external
  {
    uint igi = ProductModel(Model(modelAddress).productModelAddress()).getItemGlobalIndex(msg.sender, localItemIndex);

    ProductModel(Model(modelAddress).productModelAddress()).addBatchOffer(igi, details);
    EventModel(Model(modelAddress).eventModelAddress()).onAddBatchOfferEmit(igi, details);
  }

  // add a private deal buyer of an item
  function setPrivateDealClient(uint localItemIndex, address buyer, bool enabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemAllowedClient(igi.sub(1), buyer, enabled);
    }
  }

  // check if a user is an eligible buyer of an item
  function isEligibleBuyer(uint igi, address buyer) external view returns (bool)
  {
    require(buyer != address(0));

    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    if(model.getItemIsDealPrivate(igi.sub(1)))
    {
      if(!model.getItemIsAllowedClient(igi.sub(1), buyer))
        return false;
    }

    return true;    
  }

  // ------------------------------------------------------------------------------------
  // Product management
  // ------------------------------------------------------------------------------------

  // enable private deal mode of an item
  function enablePrivateDeal(uint localItemIndex, bool enabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemIsDealPrivate(igi.sub(1), enabled);
    }
  }

  // check if an item is only available for private deal
  function isPrivateDealItem(uint igi) external view returns (bool)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemIsDealPrivate(igi.sub(1));
  }

  // check if an item is banned
  function isItemBanned(uint igi) view external returns(bool)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemIsBanned(igi);
  }

  // get the listed price in pegged USD of an item
  function getItemPrice(uint igi) view external returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemPrice(igi);
  } 

  // get the global item index of an item belonging to a vendor, with a local item index
  function getItemGlobalIndex(address vendor, uint localIndex) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemGlobalIndex(vendor, localIndex);
  }

  // get the no dispute period of a deal in terms of the number of blocks
  function getNoDisputePeriodOfItem(uint igi) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemNoDisputePeriod(igi.sub(1));
  }

  // get the time limit for shipping by the seller
  function getShippingPeriodOfItem(uint igi) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemShippingPeriod(igi.sub(1));
  }  

  // check if an item is available for deal request
  function isProductBlockValid(uint globalItemIndex) external view returns (bool)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).isBlockValid(globalItemIndex);
  }

  // return num of items of a vendor
  function numOfItemsOfVendor(address vendor) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemCount(vendor);
  }

  // return num of items of a category
  function numOfItemsOfCategory(uint8 category) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).numOfItemsOfCategory(category);
  }

  // get a list of item global indices under a category
  function getItemIndicesFromCategory(uint8 category) external view returns (uint[] memory)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemIndicesFromCategory(category);
  }

  // increase the quantity left of an item
  function plusProductQuantity(uint igi, uint count) external controllerOnly
  {
    ProductModel(Model(modelAddress).productModelAddress()).plusProductQuantity(igi.sub(1), count);
  }

  // decrease the quantity left of an item
  function minusProductQuantity(uint igi, uint count) external controllerOnly
  {
    ProductModel(Model(modelAddress).productModelAddress()).minusProductQuantity(igi.sub(1), count);
  }

  // update item's deal count after deal finalization, only executed by central escrow
  function addItemDealCountByOne(uint igi) external controllerOnly
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    model.setItemDealCount(igi.sub(1), model.getItemDealCount(igi.sub(1)).add(1));
  }

  // set the rating score of an item
  function addItemRatingScore(uint igi, uint score) external controllerOnly
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    model.setItemRatingScore(igi.sub(1), model.getItemRatingScore(igi.sub(1)).add(score));
  }  

  // set the active flag of an item
  function setItemActive(uint localItemIndex, bool isActive) external returns(bool)
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    uint category = model.getItemCategory(igi.sub(1));
    if(category > 0)
    {
      model.setItemIsActive(localItemIndex, isActive);

      EventModel(Model(modelAddress).eventModelAddress()).onSetItemOfCategoryEmit(category, igi, model.getItemTitle(igi.sub(1)), isActive);

      return true;
    }
    else
      return false;    
  }

  // set the title of an item
  function setItemTitle(uint localItemIndex, bytes calldata title) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemTitle(igi.sub(1), title);
    }
  }

  // set the details of an item
  function setItemDetails(uint localItemIndex, bytes calldata details) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0, 'invalid item index provided');

    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemDetail(igi, details);

      EventModel(Model(modelAddress).eventModelAddress()).onAddItemDetailsEmit(igi, localItemIndex, details);
    }
  }

  function getItemDetails(uint itemGlobalIndex) external view returns (bytes memory)
  { 
    return ProductModel(Model(modelAddress).productModelAddress()).getItemDetail(itemGlobalIndex);
  }

  // set the category index of an item
  function setItemCategory(uint localItemIndex, uint8 category) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    uint currentCategory = model.getItemCategory(igi.sub(1));
    if(currentCategory > 0)
    {
      EventModel(Model(modelAddress).eventModelAddress()).onSetItemOfCategoryEmit(category, igi, '', false);
      model.setItemCategory(igi.sub(1), category);
      EventModel(Model(modelAddress).eventModelAddress()).onSetItemOfCategoryEmit(category, igi, model.getItemTitle(igi.sub(1)), true);
    }
  }

  // set the listed price of an item in pegged token
  function setItemPrice(uint localItemIndex, uint price) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    uint currentCategory = model.getItemCategory(igi.sub(1));
    if(currentCategory > 0)
    {
      model.setItemPrice(igi.sub(1), price);
    }
  }

  // set the quantity left of an item
  function setItemQuantity(uint localItemIndex, uint quantityLeft, bool isQuantityLimited) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    uint currentCategory = model.getItemCategory(igi.sub(1));
    if(currentCategory > 0)
    {
      model.setItemQuantityLeft(igi.sub(1), quantityLeft);
      model.setItemIsQuantityLimited(igi.sub(1), isQuantityLimited);
    }
  }

  // set the no dispute period of an item in terms of the number of blocks
  function setNoDisputePeriodOfItem(uint localItemIndex, uint period) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    model.setItemNoDisputePeriod(igi.sub(1), period);
  }

  // set the shipping time limit of an item in terms of the number of blocks
  function setShippingPeriodOfItem(uint localItemIndex, uint period) external 
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    model.setItemShippingPeriod(igi.sub(1), period);
  }

  // add an item
  function addItem(uint8 category, uint price, bytes calldata title, bytes calldata details, uint quantityLeft, bool isQuantityLimited, uint noDisputePeriod, uint shippingPeriod, uint validBlockCount) external{
    
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    model.addItem(category, price, title, quantityLeft, isQuantityLimited, noDisputePeriod, shippingPeriod, validBlockCount);

    uint igi = model.getTotalItemCount();
    model.addItemIndex(msg.sender, igi);
    model.addItemIndexToCategory(category, igi);

    model.setItemDetail(igi, details);

    EventModel(Model(modelAddress).eventModelAddress()).onAddItemDetailsEmit(igi, model.getItemCount(msg.sender).sub(1), details);
    EventModel(Model(modelAddress).eventModelAddress()).onSetItemOfCategoryEmit(category, igi, title, true);
  }

  function getItemOwner(uint itemGlobalIndex) external view returns (address)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemOwner(itemGlobalIndex);
  }

  // return the item details from a vendor, by given a local index
  function getItemByVendor(address vendor, uint localItemIndex) external view returns (uint8, uint, bool, bytes memory, uint, uint, uint, bool, uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemByVendor(vendor, localItemIndex);
  }

  // get an item by given a global item index
  function getItemByGlobal(uint igi) external view returns (uint8, uint, bool, bytes memory, uint, uint, uint, bool, uint, uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemByGlobalIndex(igi.sub(1));
  }
  
}