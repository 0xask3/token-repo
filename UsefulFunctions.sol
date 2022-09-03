// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

pragma solidity ^0.8.10;

contract UsefulFunctions is Ownable{

    using SafeMath for uint256;

    struct BuyFee {
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 devFee;
        uint16 lotteryFee;
    }

    struct SellFee {
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 devFee;
        uint16 lotteryFee;
    }

    BuyFee public buyFee;
    SellFee public sellFee;
    uint16 private totalBuyFee;
    uint16 private totalSellFee;

    bool public isTradingEnabled;

    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public _isBlackListed;

    IUniswapV2Router02 private router =
        IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); 

    uint256 public maxBuyAmount = 1 * 10**7 * 10**18;
    uint256 public maxSellAmount = 1 * 10**7 * 10**18;
    uint256 public maxWalletAmount = 1 * 10**8 * 10**18;
    
    uint256 public dailyLimit;
    mapping(address => uint256) private lastSoldTime;
    mapping(address => uint256) private soldTokenin24Hrs;

    constructor() {
        buyFee.liquidityFee = 20;
        buyFee.marketingFee = 10;
        buyFee.devFee = 10;
        buyFee.lotteryFee = 20;
        totalBuyFee = 60;

        sellFee.liquidityFee = 30;
        sellFee.marketingFee = 15;
        sellFee.devFee = 15;
        sellFee.lotteryFee = 30;
        totalSellFee = 90;
    }

    function claimStuckTokens(address _token) external onlyOwner {
        require(_token != address(this), "No rugs");
        if (_token == address(0x0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }
        IERC20 erc20token = IERC20(_token);
        uint256 balance = erc20token.balanceOf(address(this));
        erc20token.transfer(owner(), balance);
    }

    function setBlackList(address addr, bool value) external onlyOwner {
        _isBlackListed[addr] = value;
    }
    
    function setDailyLimit(uint256 value) external onlyOwner {
        dailyLimit = value;
    }

    function enableTrading() external onlyOwner {
        isTradingEnabled = true;
    }

    function setSellFee(
        uint16 lottery,
        uint16 marketing,
        uint16 liquidity,
        uint16 dev
    ) external onlyOwner {
        sellFee.lotteryFee = lottery;
        sellFee.marketingFee = marketing;
        sellFee.liquidityFee = liquidity;
        sellFee.devFee = dev;
        totalSellFee = lottery + marketing + liquidity + dev;
    }

    function setBuyFee(
        uint16 lottery,
        uint16 marketing,
        uint16 liquidity,
        uint16 dev
    ) external onlyOwner {
        buyFee.lotteryFee = lottery;
        buyFee.marketingFee = marketing;
        buyFee.liquidityFee = liquidity;
        buyFee.devFee = dev;
        totalBuyFee = lottery + marketing + liquidity + dev;
    }

    function setMaxWallet(uint256 value) external onlyOwner {
        maxWalletAmount = value;
    }

    function setMaxBuyAmount(uint256 value) external onlyOwner {
        maxBuyAmount = value;
    }

    function setMaxSellAmount(uint256 value) external onlyOwner {
        maxSellAmount = value;
    }
 

    function getPriceOfToken(uint256 amount)
        public
        view
        returns (uint256 price)
    {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        price = (uniswapV2Router.getAmountsOut(amount, path))[path.length - 1];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal view {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!_isBlackListed[from] && !_isBlackListed[to],"Account is blacklisted");

        bool takeFee;

        if (takeFee) {
            require(isTradingEnabled,"Trading not enabled yet");

            if (!automatedMarketMakerPairs[to]) {
                require(
                    balanceOf(to) + amount <= maxWalletAmount,
                    "Balance exceeds limit"
                );
            }

            uint256 fees;

            if (automatedMarketMakerPairs[to]) {
                if(block.timestamp - lastSoldTime[from] > 1 days){
                    soldTokenin24Hrs[from] = 0;
                }
                
                require(soldTokenin24Hrs[from] + amount <= dailyLimit,
                        "Token amount exceeds daily limit");

                soldTokenin24Hrs[from] = soldTokenin24Hrs[from].add(amount);
                lastSoldTime[from] = block.timestamp;
                
                require(amount <= maxSellAmount, "Sell exceeds limit");
                fees = totalSellFee;
            } else if (automatedMarketMakerPairs[from]) {
                require(amount <= maxBuyAmount, "Buy exceeds limit");
                fees = totalBuyFee;
            }
            
            uint256 feeAmount = amount.mul(fees).div(1000);
            amount = amount.sub(feeAmount);
            super._transfer(from, address(this), feeAmount);
        }

    }
}
