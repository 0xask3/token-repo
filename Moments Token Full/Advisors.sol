//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;


interface IBEP20 {

    function totalSupply() external view returns (uint256);


    function decimals() external view returns (uint8);


    function symbol() external view returns (string memory);


    function name() external view returns (string memory);


    function getOwner() external view returns (address);


    function balanceOf(address account) external view returns (uint256);


    function transfer(address recipient, uint256 amount) external returns (bool);


    function allowance(address _owner, address spender) external view returns (uint256);


    function approve(address spender, uint256 amount) external returns (bool);


    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Math operations with safety checks that throw on overflows.
 */
library SafeMath {

    function mul (uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b);
        return c;
    }
    
    function div (uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }
    
    function sub (uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add (uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
        return c;
    }

}

contract AdvisorsTokensVesting {

    using SafeMath for uint256;


    IBEP20 public Token;


    address public withdrawAddress;


    struct VestingStage {
        uint256 date;
        uint256 tokensUnlockedPercentage;
    }


    VestingStage[12] public stages;


    uint256 public vestingStartTimestamp = 1529398800;


    uint256 public initialTokensBalance;


    uint256 public tokensSent;


    event Withdraw(uint256 amount, uint256 timestamp);


    modifier onlyWithdrawAddress () {
        require(msg.sender == withdrawAddress);
        _;
    }

    /**
     * We are filling vesting stages array right when the contract is deployed.
     *
     * @param token Address of DreamToken that will be locked on contract.
     * @param withdraw Address of tokens receiver when it is unlocked.
     */
    constructor (IBEP20 token, address withdraw) public {
        Token = token;
        withdrawAddress = withdraw;
        initVestingStages();
    }
    
    /**
     * Fallback 
     */
    receive() external payable {
        withdrawTokens();
    }


    /**
     * Setup array with vesting stages dates and percents.
     */
    function initVestingStages () internal {
        uint256 month = 30 days;
        uint256 startPercent = 83;
        for(uint256 i = 0; i < 12; i++){
            stages[i].date = vestingStartTimestamp + (i * month);
            stages[i].tokensUnlockedPercentage = i * startPercent;
        }
        stages[11].tokensUnlockedPercentage = 1000; //For rounding error
    }

    /**
     * Main method for withdraw tokens from vesting.
     */
    function withdrawTokens () onlyWithdrawAddress private {
        // Setting initial tokens balance on a first withdraw.
        if (initialTokensBalance == 0) {
            setInitialTokensBalance();
        }
        uint256 tokensToSend = getAvailableTokensToWithdraw();
        sendTokens(tokensToSend);
    }

    /**
     * Set initial tokens balance when making the first withdrawal.
     */
    function setInitialTokensBalance () private {
        initialTokensBalance = Token.balanceOf(address(this));
    }

    /**
     * Send tokens to withdrawAddress.
     * 
     * @param tokensToSend Amount of tokens will be sent.
     */
    function sendTokens (uint256 tokensToSend) private {
        if (tokensToSend > 0) {
            // Updating tokens sent counter
            tokensSent = tokensSent.add(tokensToSend);
            // Sending allowed tokens amount
            Token.transfer(withdrawAddress, tokensToSend);
            // Raising event
            emit Withdraw(tokensToSend, now);
        }
    }

    /**
     * Calculate tokens available for withdrawal.
     *
     * @param tokensUnlockedPercentage Percent of tokens that are allowed to be sent.
     *
     * @return Amount of tokens that can be sent according to provided percentage.
     */
    function getTokensAmountAllowedToWithdraw (uint256 tokensUnlockedPercentage) private view returns (uint256) {
        uint256 totalTokensAllowedToWithdraw = initialTokensBalance.mul(tokensUnlockedPercentage).div(1000);
        uint256 unsentTokensAmount = totalTokensAllowedToWithdraw.sub(tokensSent);
        return unsentTokensAmount;
    }

    /**
     * Get tokens unlocked percentage on current stage.
     * 
     * @return Percent of tokens allowed to be sent.
     */
    function getTokensUnlockedPercentage () private view returns (uint256) {
        uint256 allowedPercent;
        
        for (uint8 i = 0; i < stages.length; i++) {
            if (now >= stages[i].date) {
                allowedPercent = stages[i].tokensUnlockedPercentage;
            }
        }
        
        return allowedPercent;
    }
    
    function getAvailableTokensToWithdraw () public view returns (uint256 tokensToSend) {
        uint256 tokensUnlockedPercentage = getTokensUnlockedPercentage();
        // In the case of stuck tokens we allow the withdrawal of them all after vesting period ends.
        if (tokensUnlockedPercentage >= 1000) {
            tokensToSend = Token.balanceOf(address(this));
        } else {
            tokensToSend = getTokensAmountAllowedToWithdraw(tokensUnlockedPercentage);
        }
    }

    function getStageAttributes (uint8 index) public view returns (uint256 date, uint256 tokensUnlockedPercentage) {
        return (stages[index].date, stages[index].tokensUnlockedPercentage);
    }
}
