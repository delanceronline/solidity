// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './math/SafeMath.sol';
import './Token.sol';
import './Model.sol';

contract TokenEscrow {
  
  using SafeMath for uint256;

  Token public delaToken;
  address public modelAddress;

  uint public teamBalance;
  uint public teamClaimedCount;
  uint public teamUnclaimed = 1000 * (uint256(10) ** 18);
  uint public constant teamClaimMax = 1000 * (uint256(10) ** 18);
  uint public constant teamClaimUnit = 100 * (uint256(10) ** 18);
  uint public teamClaimCountMax;

  uint internal rewardCalledTurnover;

  modifier controllerOnly() {

    require(Model(modelAddress).isController(msg.sender), "Controller access only in token escrow");
    _;

  }
  
  modifier adminOnly() {

    require(Model(modelAddress).isAdmin(msg.sender), "Admin access only in token escrow");
    _; 

  }

  constructor(address addr)
  {
    modelAddress = addr;
    delaToken = new Token(addr);

    teamClaimCountMax = teamClaimMax.div(teamClaimUnit);
  }

  function getTokenAddress() public view returns (address){

    return address(delaToken);

  }
  
  function rewardToken(address receiver, uint amount) public controllerOnly{

    require(receiver != address(0));

    if(teamClaimedCount < teamClaimCountMax)
    {
      // reward the team
      uint totalClaimed = rewardCalledTurnover.add(amount);
      uint reminder = totalClaimed.div(teamClaimMax);      
      if(reminder > teamClaimedCount && teamClaimedCount < teamClaimCountMax)
      {
        if(reminder > teamClaimCountMax)
          reminder = teamClaimCountMax;

        uint teamAmount = (reminder.sub(teamClaimedCount)).mul(teamClaimUnit);
        teamBalance = teamBalance.add(teamAmount);
        teamUnclaimed = teamUnclaimed.sub(teamAmount);

        teamClaimedCount = reminder;
      }
      
      uint tokenEscrowBalance = delaToken.balanceOf(address(this));
      if(tokenEscrowBalance > teamClaimMax)
      {
        uint balanceLeft = tokenEscrowBalance.sub(teamClaimMax);

        // reward seller
        uint actualAmount = amount;
        if(amount > balanceLeft)
          actualAmount = balanceLeft;

        delaToken.transfer(receiver, actualAmount);
        delaToken.adjustCirculationTotal(actualAmount, 0);
      }

      rewardCalledTurnover = rewardCalledTurnover.add(amount);
    }    
  }

  function getTeamReward() public adminOnly
  {
    if(teamBalance > 0)
    {
      delaToken.transfer(msg.sender, teamBalance);
      delaToken.adjustCirculationTotal(teamBalance, 0);

      teamBalance = 0;
    }
  }

  function getTokenCirculationTotal() public view returns (uint){

    return delaToken.circulationTotal();

  }

}