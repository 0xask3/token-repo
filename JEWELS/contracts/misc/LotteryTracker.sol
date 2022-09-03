// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../math/IterableMapping.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LotteryTracker is Ownable,VRFConsumerBase {

    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private weeklyHoldersMap;
    IterableMapping.Map private monthlyHoldersMap;
    IterableMapping.Map private ultimateHoldersMap;

    mapping (address => bool) public excludedFromWeekly;
    mapping (address => bool) public excludedFromMonthly;
    mapping (address => bool) public excludedFromUltimate;

    mapping(address => uint256) private lastSoldTime; 

    uint256 public lastWeeklyDistributed;
    uint256 public lastMonthlyDistributed;

    uint256 private minTokenBalForWeekly = 10000 * 10**18;
    uint256 private minTokenBalForMonthly = 20000 * 10**18;
    uint256 private minTokenBalForUltimate = 25000 * 10**18;

    uint256 weeklyAmount;
    uint256 monthlyAmount;
    uint256 ultimateAmount;

    IERC20 private BUSD = IERC20(0xE879D7Ba401b0b8c3ec010001fb95dE120242500); //BUSD

    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult;
    uint256 private oldResult;

    event WeeklyLotteryWinners(address[10] winners,uint256 Amount);
    event MonthlyLotteryWinners(address[3] winners,uint256 Amount);
    event UltimateLotteryWinners(address winner,uint256 Amount);
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: BSC Testnet
     * Chainlink VRF Coordinator address: 0xa555fC018435bef5A13C6c6870a9d4C11DEC329C
     * LINK token address:                0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
     * Key Hash: 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186
     */

     //Current : Rinkeby testnet
    constructor() 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
        )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
        lastWeeklyDistributed = block.timestamp;
        lastMonthlyDistributed = block.timestamp;
    }

    function setLottery(uint256 amount) onlyOwner public {
        //Transfers BUSD from token contract
        BUSD.transferFrom(owner(),address(this),amount);

        //Setup amount for each draws
        weeklyAmount = weeklyAmount.add(amount.mul(125).div(1000));  // 1/8

        monthlyAmount = monthlyAmount.add(amount.mul(625).div(1000)); // 5/8

        ultimateAmount = ultimateAmount.add(amount.mul(250).div(1000)); // 2/8


    }

    function getRandomNumber() public onlyOwner returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        requestId = 0;
    }

    function excludeFromWeekly(address account) external onlyOwner {
    	excludedFromWeekly[account] = true;

    	weeklyHoldersMap.remove(account);

    }

    function excludeFromMonthly(address account) external onlyOwner {
    	excludedFromMonthly[account] = true;

    	monthlyHoldersMap.remove(account);

    }

    function excludeFromUltimate(address account) external onlyOwner {
    	excludedFromUltimate[account] = true;

    	ultimateHoldersMap.remove(account);

    }
    
    function setMinValues(uint256 weekly, uint256 monthly, uint256 ultimate) external onlyOwner {
        minTokenBalForWeekly = weekly;
        minTokenBalForMonthly = monthly;
        minTokenBalForUltimate = ultimate;
    }

    function pickWeeklyWinners() public {
        require(randomResult != oldResult,"Update random number first");

        uint256 tempRandom;
        uint256 holderCount = weeklyHoldersMap.keys.length;
        address[10] memory winners;
        address winner;
        uint8 winnerCount = 0;

        while(winnerCount < 10){
            winner = weeklyHoldersMap.getKeyAtIndex(randomResult.mod(holderCount));
            if(block.timestamp.sub(lastSoldTime[winner]) >= 7 days){
                winners[winnerCount] = winner;
                winnerCount++;
                BUSD.transfer(winner, weeklyAmount.div(10));
            }
            tempRandom = uint(keccak256(abi.encodePacked(randomResult, block.timestamp, winnerCount)));
            randomResult = tempRandom;
        }

        lastWeeklyDistributed = block.timestamp;
        oldResult = randomResult;
        weeklyAmount = 0;

        emit WeeklyLotteryWinners(winners,weeklyAmount.div(10));
    }

    function pickMonthlyWinners() public {
        require(randomResult != oldResult,"Update random number first");

        uint256 tempRandom;
        uint256 holderCount = monthlyHoldersMap.keys.length;
        address[3] memory winners;
        address winner;
        uint8 winnerCount = 0;

        while(winnerCount < 3){
            winner = monthlyHoldersMap.getKeyAtIndex(randomResult.mod(holderCount));
            if(block.timestamp.sub(lastSoldTime[winner]) >= 7 days){
                winners[winnerCount] = winner;
                winnerCount++;
                BUSD.transfer(winner, monthlyAmount.div(3));
            }
            tempRandom = uint(keccak256(abi.encodePacked(randomResult, block.timestamp, winnerCount)));
            randomResult = tempRandom;
        }

        lastMonthlyDistributed = block.timestamp;
        oldResult = randomResult;
        monthlyAmount = 0;

        emit MonthlyLotteryWinners(winners,weeklyAmount.div(3));
        
    }

    function pickUltimateWinner() public onlyOwner {
        require(randomResult != oldResult,"Update random number first");
        uint256 tempRandom;
        uint256 holderCount = ultimateHoldersMap.keys.length;
        address winner;
        uint8 winnerCount;
        
        while(winnerCount < 1){
            winner = ultimateHoldersMap.getKeyAtIndex(randomResult.mod(holderCount));
            if(block.timestamp.sub(lastSoldTime[winner]) >= 7 days){
                winnerCount++;
                BUSD.transfer(winner, ultimateAmount);
            }
            tempRandom = uint(keccak256(abi.encodePacked(randomResult, block.timestamp, winnerCount)));
            randomResult = tempRandom;
        }
        
        oldResult = randomResult;
        ultimateAmount = 0;

        emit UltimateLotteryWinners(winner,ultimateAmount);
    }

    function setAccount(address payable account, uint256 newBalance, bool isFrom) external onlyOwner {

    	if(newBalance >= minTokenBalForWeekly) {
            if(excludedFromWeekly[account]) {
    		    return;
    	    }
    		weeklyHoldersMap.set(account, newBalance);
    	}
    	else {
    		weeklyHoldersMap.remove(account);
    	}

        if(newBalance >= minTokenBalForMonthly) {
            if(excludedFromMonthly[account]) {
    		    return;
    	    }
    		monthlyHoldersMap.set(account, newBalance);
    	}
    	else {
    		monthlyHoldersMap.remove(account);
    	}

        if(newBalance >= minTokenBalForUltimate) {
            if(excludedFromUltimate[account]) {
    		    return;
    	    }
    		ultimateHoldersMap.set(account, newBalance);
    	}
    	else {
    		ultimateHoldersMap.remove(account);
    	}

        if(isFrom){
            lastSoldTime[account] = block.timestamp;
        }

    }

}