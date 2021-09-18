pragma solidity >=0.4.21 <0.6.0;

import './Model.sol';
import './Token.sol';
import './StableCoin.sol';

contract DividendPool {
  
  address public modelAddress;
  
  constructor(address addr) public
  {
    modelAddress = addr;
  }

  function claimDividend() public {

    uint amount = Token(Model(modelAddress).tokenAddress()).withdrawDividend(msg.sender);

    require(amount <= StableCoin(Model(modelAddress).stableCoinAddress()).balanceOf(address(this)), "dividend withrawal amount must be smaller than total pool amount");

    if(amount > 0)
      StableCoin(Model(modelAddress).stableCoinAddress()).transfer(msg.sender, amount);

  }

}
