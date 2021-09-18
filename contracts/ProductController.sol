pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './ProductModel.sol';
import './OrderModel.sol';
import './StableCoin.sol';
import './Token.sol';
import './TokenEscrow.sol';
import './OrderEscrow.sol';

contract ProductController {
  
  using SafeMath for uint256;

  address public modelAddress;

  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product controller");
    _; 

  }

  modifier moderatorOnly() {

    require(Model(modelAddress).isModerator(msg.sender), "Moderator access only in product controller");
    _;

  }

   modifier controllerOnly(){

    require(Model(modelAddress).isController(msg.sender), "Controller access only in product controller");
    _;

   }

  constructor(address addr) public
  {
    modelAddress = addr;
  }
  
  // ------------------------------------------------------------------------------------
  // User setting
  // ------------------------------------------------------------------------------------

  function addClientDiscount(address client, uint igi, uint8 discountRate, bytes calldata details) external
  {
    require(client != address(0));

    EventModel(Model(modelAddress).eventModelAddress()).onAddDiscountToClientEmit(msg.sender, client, igi, discountRate, details);
  }

  function addBatchOffer(uint localItemIndex, bytes calldata details) external
  {
    uint igi = ProductModel(Model(modelAddress).productModelAddress()).getItemGlobalIndex(msg.sender, localItemIndex);
    EventModel(Model(modelAddress).eventModelAddress()).onAddBatchOfferEmit(igi, details);
  }

  function setPrivateDealClient(uint localItemIndex, address buyer, bool enabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemAllowedClient(igi.sub(1), buyer, enabled);
    }
  }

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

  function setFavourItem(uint igi, bool isEnabled) external
  {
    EventModel(Model(modelAddress).eventModelAddress()).onSetFavourItemEmit(msg.sender, igi, isEnabled);
  }

  // ------------------------------------------------------------------------------------
  // Product management
  // ------------------------------------------------------------------------------------

  function enablePrivateDeal(uint localItemIndex, bool enabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      model.setItemIsDealPrivate(igi.sub(1), enabled);
    }
  }

  function isPrivateDealItem(uint igi) external view returns (bool)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemIsDealPrivate(igi.sub(1));
  }

  function isItemBanned(uint igi) view external returns(bool)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemIsBanned(igi);
  }

  function getItemPriceUSD(uint igi) view external returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemPriceUSD(igi);
  } 

  // get the global item index of an item belonging to a vendor, with a local item index
  function getItemGlobalIndex(address vendor, uint localIndex) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemGlobalIndex(vendor, localIndex);
  }

  function getNoDisputePeriodOfItem(uint igi) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemNoDisputePeriod(igi.sub(1));
  }

  function getShippingPeriodOfItem(uint igi) external view returns (uint)
  {
    return ProductModel(Model(modelAddress).productModelAddress()).getItemShippingPeriod(igi.sub(1));
  }  

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

  function plusProductQuantity(uint igi, uint count) external controllerOnly
  {
    ProductModel(Model(modelAddress).productModelAddress()).plusProductQuantity(igi.sub(1), count);
  }

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

  function addItemRatingScore(uint igi, uint score) external controllerOnly
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    model.setItemRatingScore(igi.sub(1), model.getItemRatingScore(igi.sub(1)).add(score));
  }

  function setItemBanned(uint igi, bool isBanned) adminOnly external
  {
    ProductModel(Model(modelAddress).productModelAddress()).setItemIsBanned(igi, isBanned);    
  }

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

  function setItemDetails(uint localItemIndex, bytes calldata details) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    if(model.getItemCategory(igi.sub(1)) > 0)
    {
      EventModel(Model(modelAddress).eventModelAddress()).onAddItemDetailsEmit(igi, localItemIndex, details);
    }
  }

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

  function setItemPrice(uint localItemIndex, uint priceUSD) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    uint currentCategory = model.getItemCategory(igi.sub(1));
    if(currentCategory > 0)
    {
      model.setItemPriceUSD(igi.sub(1), priceUSD);
    }
  }

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

  function setItemTag(uint localItemIndex, bytes32 lowerCaseHash, bytes32 originalHash, bytes calldata tag, bool isEnabled) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    require(model.getItemCount(msg.sender) > 0, "You can only edit your own item.");

    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    require(model.getItemCategory(igi.sub(1)) != 0);

    EventModel(Model(modelAddress).eventModelAddress()).onSetItemTagEmit(igi, lowerCaseHash, originalHash, tag, isEnabled);
  }

  function setNoDisputePeriodOfItem(uint localItemIndex, uint period) external
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    model.setItemNoDisputePeriod(igi.sub(1), period);
  }

  function setShippingPeriodOfItem(uint localItemIndex, uint period) external 
  {
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());
    uint igi = model.getItemGlobalIndex(msg.sender, localItemIndex);
    require(igi > 0);

    model.setItemShippingPeriod(igi.sub(1), period);
  }

  // add an item
  function addItem(uint8 category, uint priceUSD, bytes calldata title, bytes calldata details, uint quantityLeft, bool isQuantityLimited, uint noDisputePeriod, uint shippingPeriod, uint validBlockCount) external{
    
    ProductModel model = ProductModel(Model(modelAddress).productModelAddress());

    model.addItem(category, priceUSD, title, quantityLeft, isQuantityLimited, noDisputePeriod, shippingPeriod, validBlockCount);

    uint igi = model.getTotalItemCount();
    model.addItemIndex(msg.sender, igi);
    model.addItemIndexToCategory(category, igi);

    EventModel(Model(modelAddress).eventModelAddress()).onAddItemDetailsEmit(igi, model.getItemCount(msg.sender).sub(1), details);
    EventModel(Model(modelAddress).eventModelAddress()).onSetItemOfCategoryEmit(category, igi, title, true);
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

  // ---------------------------------------
  // ---------------------------------------    
  
}