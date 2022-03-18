// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './EventModel.sol';
import './SharedStructs.sol';

/*
------------------------------------------------------------------------------------

This is a customized model for the items / products hashtags which is only accessible by the controller.

------------------------------------------------------------------------------------
*/

contract HashTagModel {

  using SafeMath for uint256;

  address public modelAddress;  

  // controller only modifier
  modifier controllerOnly()
  {
    require(Model(modelAddress).isController(msg.sender), "Controller access only in main model");
    _;
  }

  // administrator only modiifer
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in product model");
    _; 

  }

  // hash tags for items
  mapping (bytes => SharedStructs.HashTag[]) public hashTags;
  mapping (bytes => uint) public hashTagsHeadIndices;

  mapping (uint => bytes[]) public itemIndexHashTagsMap;

  constructor(address addr)
  {
    modelAddress = addr;
  }

  // ------------------------------------------------------------------------------------   
  // Data access
  // ------------------------------------------------------------------------------------  

  function addHashTag(bytes calldata lowerCaseHash, uint igi, bytes calldata tag, bool isEnabled) external controllerOnly
  {
    require(lowerCaseHash.length > 0, 'lowerCaseHash must be non-empty');
    require(tag.length > 0, 'tag must be non-empty');

    bool bFound = false;
    for(uint i = 0; i < itemIndexHashTagsMap[igi].length; i++)
    {
      if(keccak256(itemIndexHashTagsMap[igi][i]) == keccak256(lowerCaseHash))
      {
        bFound = true;
        break;
      }
    }

    require(!bFound, 'hashtag already exists');

    SharedStructs.HashTag memory hashTag;
    hashTag.igi = igi;
    hashTag.tag = tag;
    hashTag.isEnabled = isEnabled;
    hashTag.blockNumber = block.number;

    if(hashTags[lowerCaseHash].length > 0)
    {
      hashTag.hookTo = hashTags[lowerCaseHash].length;

      SharedStructs.HashTag storage previousHashTag = hashTags[lowerCaseHash][hashTags[lowerCaseHash].length - 1];
      previousHashTag.hookBy = hashTags[lowerCaseHash].length + 1;
    }

    hashTags[lowerCaseHash].push(hashTag);
    itemIndexHashTagsMap[igi].push(lowerCaseHash);
  }

  function setHashTag(uint index, bytes calldata lowerCaseHash, uint igi, bool isEnabled, uint hookTo, uint hookBy) external controllerOnly
  {
    SharedStructs.HashTag storage hashTag = hashTags[lowerCaseHash][index];
    hashTag.igi = igi;
    hashTag.isEnabled = isEnabled;
    hashTag.hookTo = hookTo;
    hashTag.hookBy = hookBy;
  }

  function enableHashTag(bytes calldata lowerCaseHash, uint igi, bool isEnabled) external controllerOnly
  {
    SharedStructs.HashTag[] storage tags = hashTags[lowerCaseHash];

    for(uint i = 0; i < tags.length; i++)
    {
      if(igi == tags[i].igi)
      {
        if(tags[i].isEnabled != isEnabled)
        {
          bytes[] storage tagList = itemIndexHashTagsMap[igi];
          for(uint j = 0; j < tagList.length; j++)
          {
            if(keccak256(tagList[j]) == keccak256(lowerCaseHash))
            {
              if(tags[i].isEnabled)
              {
                // remove tag from itemIndexHashTagsMap[igi]
                tagList[j] = tagList[tagList.length - 1];
                tagList.pop();
              }
              else
              {
                // add tag to itemIndexHashTagsMap[igi]
                tagList.push(tags[i].tag);
              }

              break;
            }
          }

          tags[i].isEnabled = isEnabled;          
        }

        break;
      }
    }
  }

  function detachHashTagFromOrderingChain(bytes calldata lowerCaseHash, uint currentIndex) internal
  {
    SharedStructs.HashTag[] storage tags = hashTags[lowerCaseHash];
    SharedStructs.HashTag storage currentHashTag = tags[currentIndex];
    
    if(currentHashTag.hookTo == 0)
    {
      // the current tag is the first one on the ordering chain
      
      if(currentHashTag.hookBy > 0)
      {
        // the current tag is not the only one on the chain
        // set the hook of the next one to null
        SharedStructs.HashTag storage backHashTag = tags[currentHashTag.hookBy - 1];
        backHashTag.hookTo = 0;
      }
    }
    else if(currentHashTag.hookBy == 0)
    {
      // the current tag is the last one on the ordering chain

      if(currentHashTag.hookTo > 0)
      {
        // the current tag is not the only one on the chain
        // set the hook of the front one to null
        SharedStructs.HashTag storage frontHashTag = tags[currentHashTag.hookTo - 1];        
        frontHashTag.hookBy = 0;
      }
    }
    else
    {
      // in the middle of the ordering chain
      SharedStructs.HashTag storage frontHashTag = tags[currentHashTag.hookTo - 1];
      SharedStructs.HashTag storage backHashTag = tags[currentHashTag.hookBy - 1]; 

      frontHashTag.hookBy = currentHashTag.hookBy;
      backHashTag.hookTo = currentHashTag.hookTo;
    }

  }

  function appendHashTagIntoOrderingChain(bytes calldata lowerCaseHash, uint currentIndex, uint targetIndex) internal
  {
    SharedStructs.HashTag[] storage tags = hashTags[lowerCaseHash];
    SharedStructs.HashTag storage currentHashTag = tags[currentIndex];
    SharedStructs.HashTag storage targetHashTag = tags[targetIndex];

    if(targetHashTag.hookTo == 0)
    {
      // the target tag is the first one on the ordering chain
      currentHashTag.hookTo = 0;
      currentHashTag.hookBy = targetIndex + 1;        

      targetHashTag.hookTo = currentIndex + 1;

      hashTagsHeadIndices[lowerCaseHash] = currentIndex;
    }
    else if(targetHashTag.hookBy == 0)
    {
      // the target tag is the last one on the ordering chain
      targetHashTag.hookBy = currentIndex + 1;

      currentHashTag.hookTo = targetIndex + 1;
      currentHashTag.hookBy = 0;      
    }
    else
    {
      // in the middle of the ordering chain
      SharedStructs.HashTag storage frontHashTag = tags[targetHashTag.hookTo - 1]; 

      currentHashTag.hookTo = targetHashTag.hookTo;
      currentHashTag.hookBy = targetIndex + 1;

      frontHashTag.hookBy = currentIndex + 1;
      targetHashTag.hookTo = frontHashTag.hookBy;
    }
  }

  // currentIndex and hookToIndex are zero based
  function modifyHashTagOrderingPosition(bytes calldata lowerCaseHash, uint currentIndex, uint pointToIndex) external controllerOnly
  {
    detachHashTagFromOrderingChain(lowerCaseHash, currentIndex);
    appendHashTagIntoOrderingChain(lowerCaseHash, currentIndex, pointToIndex);
  }

  function getHashTags(bytes calldata lowerCaseHash) external view controllerOnly returns (SharedStructs.HashTag[] memory)
  {
    return hashTags[lowerCaseHash];
  }

  function getItemHashTags(uint igi) external view controllerOnly returns (bytes[] memory)
  {
    return itemIndexHashTagsMap[igi];
  }

  function getHeadIndexOfHashTags(bytes calldata lowerCaseHash) external view controllerOnly returns (uint)
  {
    return hashTagsHeadIndices[lowerCaseHash];
  }
}