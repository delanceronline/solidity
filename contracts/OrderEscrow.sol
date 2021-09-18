pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './Token.sol';
import './StableCoin.sol';

contract OrderEscrow {
  
  using SafeMath for uint256;

  address public modelAddress;

  modifier controllerOnly() {

    require(Model(modelAddress).isController(msg.sender), "Controller access only in order escrow");
    _;

  }

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  function transferStabeCoin(address receiver, uint amount) external controllerOnly
  {
    // if receiver is token pool, update stable coin inflow to token pool.
    if(receiver == Model(modelAddress).dividendPoolAddress())
    {
      Token(Model(modelAddress).tokenAddress()).updatePoolInflow(amount);
    }

    StableCoin(Model(modelAddress).stableCoinAddress()).transfer(receiver, amount);
  }
  
}