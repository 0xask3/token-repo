// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./math/IterableMapping.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "./misc/LotteryTracker.sol";


contract GodShiba is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;
    bool private isAlreadyCalled;
    bool private isTradingEnabled;

    LotteryTracker public lotteryTracker;

    address private constant deadWallet = address(0xdead);

    uint256 public swapTokensAtAmount = 1 * 10**6 * (10**18);
    uint256 public dailyLimit = 20 * 10**6 * 10**18;
    
    mapping(address => uint256) private lastSoldTime;
    mapping(address => uint256) private soldTokenin24Hrs;

    uint8 public liquidityFee = 10;
    uint8 public marketingFee = 25;
    uint8 public lotteryFee = 5;

    address public _marketingWalletAddress = address(0x123);

     // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;


    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier onlyLottery{
        require(msg.sender == address(lotteryTracker),"Only lottery contract");
        _;
    }

    constructor() ERC20("God Shiba", "GSHIB") {

        lotteryTracker = new LotteryTracker();


    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from receiving dividends

        lotteryTracker.excludeFromLottery(uniswapV2Pair);
        lotteryTracker.excludeFromLottery(owner());
        lotteryTracker.excludeFromLottery(address(this));

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(_marketingWalletAddress, true);
        excludeFromFees(address(this), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1000000000 * (10**18));
    }

    receive() external payable {

  	}

    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "GSHIB: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "GSHIB: Account is already excluded");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setMarketingWallet(address payable wallet) external onlyOwner{
        _marketingWalletAddress = wallet;
    }

    function setLiquidityFee(uint8 value) external onlyOwner{
        liquidityFee = value;
    }

    function setMarketingFee(uint8 value) external onlyOwner{
        marketingFee = value;
    }

    function setLotteryFee( uint8 _lottery) external onlyOwner{
        lotteryFee = _lottery;
    }

    function enableTrading() external onlyOwner{
        isTradingEnabled = true;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "GSHIB: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }


    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "GSHIB: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function excludeFromLottery(address account) external onlyOwner{
	    lotteryTracker.excludeFromLottery(account);
	}
	
	function setMinValue(uint256 _lottery) external onlyOwner {
	    lotteryTracker.setMinValue(_lottery);
	}

    function setDailyLimit(uint256 _limit) external onlyOwner {
	    dailyLimit = _limit;
	}

    function pickLotteryWinner() external onlyOwner{
	    if(!isAlreadyCalled){ 
                lotteryTracker.getRandomNumber();
                isAlreadyCalled = true;
            }else{
                try lotteryTracker.pickLotteryWinner() {isAlreadyCalled = false;} catch {}
            }
	}

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

		uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if( canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != owner() &&
            to != owner()
        ) {
            swapping = true;

            swapAndLiquify(contractTokenBalance);

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {
            if(automatedMarketMakerPairs[to]){
                require(isTradingEnabled,"Trading not enabled yet");

                if(block.timestamp - lastSoldTime[from] > 1 days){
                    lastSoldTime[from] = block.timestamp;
                    soldTokenin24Hrs[from] = 0;
                }
                
                require(soldTokenin24Hrs[from] + amount < dailyLimit,
                        "Token amount exceeds daily limit");

                soldTokenin24Hrs[from] = soldTokenin24Hrs[from].add(amount);
            }

        	uint256 marketingTokens = amount.mul(marketingFee).div(1000);
            super._transfer(from, _marketingWalletAddress, marketingTokens);

            uint256 swapTokens = amount.mul(liquidityFee).div(1000);
            super._transfer(from, address(this), swapTokens);

            uint256 lotteryTokens = amount.mul(lotteryFee).div(1000);
            super._transfer(from, address(lotteryTracker), lotteryTokens);

            amount = amount.sub(marketingTokens.add(swapTokens).add(lotteryTokens));
        }

        super._transfer(from, to, amount);

        try lotteryTracker.setAccount(payable(from), balanceOf(from), true) {} catch {}
        try lotteryTracker.setAccount(payable(to), balanceOf(to), false) {} catch {}

    }

    function swapAndLiquify(uint256 tokens) private {
       // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }


    function swapTokensForEth(uint256 tokenAmount) private {


        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );

    }
}