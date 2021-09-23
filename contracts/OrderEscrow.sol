pragma solidity >=0.4.21 <0.6.0;

import "./math/SafeMath.sol";
import './Model.sol';
import './Token.sol';
import './StableCoin.sol';

/*
------------------------------------------------------------------------------------

This is an order escrow class for holding all pegged tokens (USD) of all on-going deals

------------------------------------------------------------------------------------
*/

contract OrderEscrow {
  
  using SafeMath for uint256;

  address public modelAddress;

  // order controllers only modifier
  modifier orderControllerOnly() {

    require(msg.sender == Model(modelAddress).orderDetailsControllerAddress() || msg.sender == Model(modelAddress).orderManagementControllerAddress() || msg.sender == Model(modelAddress).orderSettlementControllerAddress(), "Order controller access only in order model");
    _;

  }

  constructor(address addr) public
  {
    modelAddress = addr;
  }

  // transfer pegged tokens to somewhere, including to the dividend pool
  function transferStabeCoin(address receiver, uint amount) external orderControllerOnly
  {
    // if receiver is the dividend pool, update stable coin inflow to the dividend pool.
    if(receiver == Model(modelAddress).dividendPoolAddress())
    {
      Token(Model(modelAddress).tokenAddress()).updatePoolInflow(amount);
    }

    StableCoin(Model(modelAddress).stableCoinAddress()).transfer(receiver, amount);
  }
  
}