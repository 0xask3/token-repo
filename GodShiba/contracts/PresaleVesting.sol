// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.6;

contract PresaleVesting is Context, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct Stage {
        uint256 date;
        uint256 tokensUnlockedPercentage;
    }
    
    struct User{
        uint256 initialBalance;
        uint256 lockedAmount;
        uint256 totalWithdrawn;
    }

    struct Round{
        uint256 weiRaised;
        uint256 rate;
        address payable fundWallet;
        uint256 divider;
        uint256 totalBalance;
        uint256 remainingBalance;
        uint256 startTimestamp;
        bool isActive;
    }

    Stage[4] public stages;
    Round[2] public round;

    // The token being sold
    IERC20 private _token;  
    
    //To denote current round
    uint8 public _counter;
    
    mapping(uint8 => mapping(address => User)) public users;

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event Withdraw(uint256 tokensToSend,uint256 now);

    constructor (IERC20 token1) {
        _token = token1;
    }

    receive() external payable {
        buyTokens(_msgSender());
    }

    function token() public view returns (IERC20) {
        return _token;
    }

    function wallet(uint8 rnd) public view returns (address payable) {
        return round[rnd].fundWallet;
    }

    function rate(uint8 rnd) public view returns (uint256) {
        return round[rnd].rate;
    }
    
    function divider(uint8 rnd) public view returns (uint256) {
        return round[rnd].divider;
    }

    function weiRaised(uint8 rnd) public view returns (uint256) {
        return round[rnd].weiRaised;
    }

    function buyTokens(address beneficiary) public nonReentrant payable {
        require(round[_counter].isActive,"Sale already ended! / Not started yet");
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(_counter,weiAmount);

        // update state
        round[_counter].weiRaised = round[_counter].weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
        _forwardFunds(_counter);

    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        users[_counter][beneficiary].lockedAmount = users[_counter][beneficiary].lockedAmount.add(tokenAmount);
        users[_counter][beneficiary].initialBalance = users[_counter][beneficiary].initialBalance.add(tokenAmount);
        round[_counter].remainingBalance = round[_counter].remainingBalance.sub(tokenAmount);
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _deliverTokens(beneficiary, tokenAmount);
    }

    function _getTokenAmount(uint8 rnd, uint256 weiAmount) public view returns (uint256) {
        return weiAmount.mul(round[rnd].rate).div(round[rnd].divider);
    }

    function _forwardFunds(uint8 rnd) internal {
        round[rnd].fundWallet.transfer(msg.value);
    }
    
    // Owner only function to withdraw any unsold token and stop sale
    function endRound() external nonReentrant onlyOwner{
        require(round[_counter].isActive,"Round not started yet");
        round[_counter].isActive = false;
        _token.transfer(owner(), round[_counter].remainingBalance);
        delete round[_counter].totalBalance;
        delete round[_counter].remainingBalance;
        _counter++;
    }
    
    //Function to be called to start sale
    function startRound(uint256 amount, uint256 rate1, address wallet1, uint256 divider1) external onlyOwner{
        require(rate1 > 0, "Crowdsale: rate is 0");
        require(divider1 > 0, "Crowdsale: divider is 0");
        require(wallet1 != address(0), "Crowdsale: wallet is the zero address");
        require(!round[_counter].isActive,"Buy is already active");

        _token.transferFrom(_msgSender(), address(this), amount);

        round[_counter].totalBalance = amount;
        round[_counter].remainingBalance = amount;
        round[_counter].isActive = true;
        round[_counter].rate = rate1;
        round[_counter].divider = divider1;
        round[_counter].fundWallet = payable(wallet1);

    }
    function startVesting() external onlyOwner {
        initStages(0);
        initStages(1);
    }
    
    function withdrawTokens (uint8 rnd) public {
        require(!round[rnd].isActive,"Sale is still active");
        uint256 tokensToSend = getTokensUnlocked(rnd,msg.sender);
        if (tokensToSend > 0) {
            // Updating tokens sent counter
            users[rnd][msg.sender].totalWithdrawn = users[rnd][msg.sender].totalWithdrawn.add(tokensToSend);
            users[rnd][msg.sender].lockedAmount = users[rnd][msg.sender].lockedAmount.sub(tokensToSend);
            // Sending allowed tokens amount
            _token.transfer(msg.sender, tokensToSend);
            // Raising event
            emit Withdraw(tokensToSend, block.timestamp);
        }
    }
    
    function initStages(uint8 rnd) internal {
        round[rnd].startTimestamp = block.timestamp;
        uint256 month = 30 days;
        stages[0].date = round[rnd].startTimestamp;
        stages[1].date = round[rnd].startTimestamp + (1 * month);
        stages[2].date = round[rnd].startTimestamp + (2 * month);
        stages[3].date = round[rnd].startTimestamp + (3 * month);
        
        stages[0].tokensUnlockedPercentage = 400; 
        stages[1].tokensUnlockedPercentage = 600;
        stages[2].tokensUnlockedPercentage = 800;
        stages[3].tokensUnlockedPercentage = 1000;
        
    }

    function getTokensUnlocked(uint8 rnd, address addr) public view returns(uint256 tokensToSend) {
        uint256 allowedPercent;
        // Getting unlocked percentage
        for (uint8 i = 0; i < stages.length; i++) {
            if (block.timestamp >= stages[i].date) {
                allowedPercent = stages[i].tokensUnlockedPercentage;
            }
        }
        if (allowedPercent >= 1000) {
            tokensToSend = users[rnd][addr].lockedAmount;
        } else {
            uint256 totalTokensAllowedToWithdraw = users[rnd][addr].initialBalance.mul(allowedPercent).div(1000);
            tokensToSend = totalTokensAllowedToWithdraw.sub(users[rnd][addr].totalWithdrawn);
            return tokensToSend;
        }
    }
    
    
}