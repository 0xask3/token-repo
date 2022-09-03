//SPDX-License-Identifier: UNLICENSED
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.4;

contract PointSystem is Ownable{
    
    IERC20 public immutable MNG; //Token contract address
    
    uint8 private immutable decimals; // Decimals of the token
    
    mapping(address => mapping(uint8 => uint256)) private userPoints; //Mapping to store points
    
    uint256[50] public ratio = [10,15,20,25,30,35,40,45,50]; //Ratio store

    event PointsBought(uint256 token, uint8 ratio, uint256 points);
    event RatioChanged(uint8 ratioSelector,uint256 ratioValue);
    event PointsSold(uint256 token, uint8 ratio, uint256 points);
    event PointsDeducted(uint8 ratioSelector,uint256 points);
    event PointsAdded(address user,uint8 ratioSelector,uint256 points);

    constructor(IERC20 _MNG, uint8 _decimals){
        MNG = _MNG;
        decimals = _decimals;
    }

/*
    Function to buy points using token
    
    tokenAmount = Amount of token you want to spend
    ratioSelector = On which ratio you want to receive points

    **Important! You must approve tokens before calling this function
    Approve this contract to spend MNG tokens on your behalf

*/
    function buyPoints(uint256 tokenAmount, uint8 ratioSelector) external {
        require(MNG.allowance(msg.sender,address(this)) >= tokenAmount,"Set allowance first!");
        MNG.transferFrom(msg.sender,address(this),tokenAmount);

        uint256 points = (tokenAmount * ratio[ratioSelector]) / 10 ** decimals;
        userPoints[msg.sender][ratioSelector] += points;

        emit PointsBought(tokenAmount,ratioSelector,points);
    }

/*
    Function to sell points and receive token
    
    points = How much points you want to sell
    ratioSelector = On which ratio you want to receive tokens
    
    **You can only sell points in the same ratio you bought

*/     
    function sellPoints(uint256 points, uint8 ratioSelector) external {
        require(userPoints[msg.sender][ratioSelector] >= points,"You don't have enough points");
        uint256 tokenAmount = (points * 10 ** decimals) / ratio[ratioSelector];
        userPoints[msg.sender][ratioSelector] -= points;
        require(MNG.balanceOf(address(this)) >= tokenAmount,"Not enough tokens to pay");

        MNG.transfer(msg.sender, tokenAmount);
        
        emit PointsSold(tokenAmount,ratioSelector,points);
    }
    
/*
    Function to reduce point from contract and update on external database
    
    points = How much points you want to sell
    ratioSelector = On which ratio you want to receive tokens
    
    **Should listen on PointsDeducted event to know how much points is deducted 
    
*/
    function deductPoints(uint256 points, uint8 ratioSelector) external {
        require(userPoints[msg.sender][ratioSelector] >= points,"You don't have enough points");
        userPoints[msg.sender][ratioSelector] -= points;
        
        emit PointsDeducted(ratioSelector,points);
    }
    
/*
    Function to add points back from db to contract
    Can only be called by owner to prevent misuse
    
    user = Address of user to whom the points are being added
    points = How much points you want to sell
    ratioSelector = On which ratio you want to receive tokens
    
    **Should keep enough BNB to cover fee in owner wallet
    
*/
    function addPoints(address user, uint256 points, uint8 ratioSelector) external onlyOwner {
        userPoints[user][ratioSelector] += points;
        
        emit PointsAdded(user,ratioSelector,points);
    }

//View function to see your own point balance in each ratio
    function getPoints(uint8 ratioSelector) external view returns (uint256) {
        return(userPoints[msg.sender][ratioSelector]);
    }

// Owner view function to see anyones point balance in each ratio
    function getPointsOwner(address addr, uint8 ratioSelector) external view onlyOwner returns (uint256) {
        return(userPoints[addr][ratioSelector]);
    }

// Can be called to withdraw any tokens send to this contract. Including MNG token!
    function transferAnyERC20(address _tokenAddress, address _to, uint _amount) external onlyOwner {
        IERC20(_tokenAddress).transfer(_to, _amount);
    }
    
// To modify ratio system. Maximum 50 ratio allowed
    function modifyRatio(uint8 ratioSelector, uint256 ratioValue) external onlyOwner {
        ratio[ratioSelector] = ratioValue;
        emit RatioChanged(ratioSelector,ratioValue);
    }
}
