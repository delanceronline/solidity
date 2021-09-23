pragma solidity >=0.4.21 <0.6.0;

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
  
  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // function for claiming dividend called by DELA holders  
  function claimDividend() public {

    uint amount = Token(Model(modelAddress).tokenAddress()).withdrawDividend(msg.sender);

    require(amount <= StableCoin(Model(modelAddress).stableCoinAddress()).balanceOf(address(this)), "dividend withdrawal amount must be smaller than total pool amount");

    if(amount > 0)
      StableCoin(Model(modelAddress).stableCoinAddress()).transfer(msg.sender, amount);

  }

}
