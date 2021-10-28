// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SharedStructs {

  // deal structure
  struct Deal{

    //0: buyer
    //1: seller
    //2: referee
    //3: moderator
    address[4] roles;

    
    //0: activationTime
    //1: shippedTime
    //2: acceptionTime
    //3: disputeExpiredDuration
    //4: totalDisputeExpiredDuration
    //5: itemGlobalIndex
    //6: quantity
    //7: amountTotal
    //8: market commission percent
    //9: shippingPeriod in blocks
    //10: moderator handling fee percent
    uint[11] numericalData;


    //0: isExtendingDealAllowed
    //1: isShipped
    //2: isFinalized
    //3: isCancelled
    //4: isAccepted
    //5: isDisputed
    //6: isDisputeResolved
    //7: shouldRefund
    //8: isRatedAndReviewedByBuyer
    //9: isRatedAndReviewedBySeller
    //10: isDirectDeal
    bool[11] flags;
    
  }

  // item's structure
  struct Item
  {
    uint8 category;                             // category index
    uint priceUSD;                              // listed price in pegged USD
    bool isActive;                              // active flag
    bytes title;                                // title of the item
    uint dealCount;                             // number of deals made
    uint ratingScore;                           // rating score by buyers
    uint quantityLeft;                          // number of items available
    bool isQuantityLimited;                     // unlimited flag
    bool isDealPrivate;                         // private deal flag
    bool isBanned;                              // ban flag
    uint noDisputePeriod;                       // number of blocks as a period which is eligible for raising a dispute of a deal
    uint shippingPeriod;                        // the time limit which the merchant has to ship the item, in number of blocks
    uint creationBlockNumber;                   // the block number at which the deal was created
    uint validBlockCount;                       // the number of blocks which after that the item will become available for deal request
  }

  // market's announcemennt structure
  struct Announcement
  {
    bytes title;
    bytes message;
    uint blockNumber;
    bool isEnabled;
  }

  // user profile structure
  struct UserProfile
  {
    bytes nickName;
    bytes about;
    string publicOpenPGPKey;
    bytes additional;
  }

  // item discount structure
  struct ItemDiscount
  {
    address client;
    uint8 discountRate;
    bytes additional;
  }

  // hash tag structure
  struct HashTag
  {
    uint igi;
    bytes tag;
    bool isEnabled;
  }

  // private message struct
  struct PrivateMessage
  {
    address sender;
    bytes details;
    bool isRead;
  }
}