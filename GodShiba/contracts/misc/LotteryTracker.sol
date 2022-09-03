// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../math/IterableMapping.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract LotteryTracker is Ownable,VRFConsumerBase {

    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private lotteryHoldersMap;

    mapping (address => bool) public excludedFromLottery;

    mapping(address => uint256) private lastSoldTime; 

    IUniswapV2Router02 private uniswapV2Router;

    uint256 private minTokenBalForLottery = 25000 * 10**18;

    IERC20 private Token; //GSHIB 

    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult;
    uint256 private oldResult;

    event LotteryWinners(address winner,uint256 Amount);
    
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
        Token = IERC20(owner());
        uniswapV2Router =  IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
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

    function excludeFromLottery(address account) external onlyOwner {
    	excludedFromLottery[account] = true;

    	lotteryHoldersMap.remove(account);

    }
    
    function setMinValue(uint256 lottery) external onlyOwner {
        minTokenBalForLottery = lottery;
    }

    function pickLotteryWinner() public onlyOwner {
        require(randomResult != oldResult,"Update random number first");
        uint256 tempRandom;
        uint256 holderCount = lotteryHoldersMap.keys.length;
        address winner;
        uint8 winnerCount;

        swapTokensForEth(Token.balanceOf(address(this)));
        
        while(winnerCount < 1){
            winner = lotteryHoldersMap.getKeyAtIndex(randomResult.mod(holderCount));
            if(block.timestamp.sub(lastSoldTime[winner]) >= 7 days){
                winnerCount++;
                payable(winner).transfer(address(this).balance);
            }
            tempRandom = uint(keccak256(abi.encodePacked(randomResult, block.timestamp, winnerCount)));
            randomResult = tempRandom;
        }
        
        oldResult = randomResult;

        emit LotteryWinners(winner, address(this).balance);
    }

    function setAccount(address payable account, uint256 newBalance, bool isFrom) external onlyOwner {

        if(newBalance >= minTokenBalForLottery) {
            if(excludedFromLottery[account]) {
    		    return;
    	    }
    		lotteryHoldersMap.set(account, newBalance);
    	}
    	else {
    		lotteryHoldersMap.remove(account);
    	}

        if(isFrom){
            lastSoldTime[account] = block.timestamp;
        }

    }

    function swapTokensForEth(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        Token.approve(address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );

    }


}