// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PrivateSale is Context, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //Amount of wei spend by user
    mapping(address => uint256) public weiSpent;

    // The token being sold
    IERC20 public _token;

    // Address where funds are collected
    address payable public _wallet;

    // How many token units a buyer gets per wei.
    uint256 public _rate;

    // To control rate if 1 wei gets less than 1 token unit
    uint256 public _divider;

    // Amount of wei raised
    uint256 public _weiRaised;
    
    //Indicates Sale is active or NOT
    bool public isActive = true;

    //HardCap for the sale
    uint256 public _hardCap;

    //Minimum amount per wallet
    uint256 public _minPerWallet;

    //Maximum amount per wallet
    uint256 public _maxPerWallet;

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * @param rate Number of token units a buyer gets per wei
     * @param divider Number of wei needed for 1 token unit
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param wallet Address where collected funds will be forwarded to
     * @param token Address of the token being sold
     * @param hardCap Maximum amount of wei which can be used to buy
     * @param minPerWallet Minimum amount of wei spent to purchase token
     * @param maxPerWallet Maximum amount of wei spent to purchase token
     */
    constructor (uint256 rate, uint256 divider, address payable wallet, 
        IERC20 token, uint256 hardCap, uint256 minPerWallet,
        uint256 maxPerWallet) {
        require(rate > 0, "Crowdsale: rate is 0");
        require(divider > 0, "Crowdsale: divider is 0");
        require(wallet != address(0), "Crowdsale: wallet is the zero address");
        require(address(token) != address(0), "Crowdsale: token is the zero address");
        require(minPerWallet <= maxPerWallet,"Crowdsale: Invalid amount limits");
        require(hardCap > 0,"Crowdsale: hardCap is 0");

        _rate = rate;
        _divider = divider;
        _wallet = wallet;
        _token = token;
        _hardCap = 550 ether;
        _minPerWallet = minPerWallet;
        _maxPerWallet = 2 ether;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {
        buyTokens(_msgSender());
    }


    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public payable {
        require(isActive,"Sale already ended!");
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _weiRaised = _weiRaised.add(weiAmount);

        _token.safeTransfer(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        weiSpent[beneficiary] = weiSpent[beneficiary].add(weiAmount);

        _wallet.transfer(msg.value);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        require(_weiRaised + weiAmount <= _hardCap,"Crowdsale: Amount exceeds hardCap");
        require(weiAmount > _minPerWallet &&
                weiSpent[beneficiary] + weiAmount < _maxPerWallet,
                "Crowdsale: Invalid purchase amount");
    }


    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(_rate).div(_divider);
    }


    function withdrawRemainingToken() external onlyOwner {
        isActive = false;
        _token.safeTransfer(owner(), _token.balanceOf(address(this)));
    }
    
}