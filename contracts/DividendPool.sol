// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Model.sol';
import './Token.sol';
import './StableCoin.sol';

/* 
------------------------------------------------------------------------------------

This is a pool holding the dividend of all DELA holders.
It holds the stable coin (pegged USD) from market's commission income.

------------------------------------------------------------------------------------
*/

contract DividendPool {
  
  address public modelAddress;
  
  constructor(address addr)
  {
    modelAddress = addr;
  }

  // function for claiming dividend called by DELA holders  
  function claimDividend(uint coinIndex) public {

    uint amount = Token(Model(modelAddress).tokenAddresses(coinIndex)).withdrawDividend(msg.sender, coinIndex);

    require(amount <= StableCoin(Model(modelAddress).stableCoinAddresses(coinIndex)).balanceOf(address(this)), "dividend withdrawal amount must be smaller than total pool amount");

    if(amount > 0)
      StableCoin(Model(modelAddress).stableCoinAddresses(coinIndex)).transfer(msg.sender, amount);

  }

}
