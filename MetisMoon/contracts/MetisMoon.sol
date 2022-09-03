// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface INetswapRouter {
    function factory() external pure returns (address);
    function Metis() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityMetis(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountMetis, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityMetis(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountMetis);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityMetisWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountMetis);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactMetisForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactMetis(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForMetis(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapMetisForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;


interface INetswapRouter02 is INetswapRouter {
    function removeLiquidityMetisSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external returns (uint amountMetis);
    function removeLiquidityMetisWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountMetis);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactMetisForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForMetisSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapMining() external pure returns (address);
}

contract MetisMoon is ERC20, Ownable {
    using SafeMath for uint256;

    INetswapRouter02 public netswapRouter;
    address public  netswapV2Pair;

    bool private swapping;

    uint256 public swapTokensAtAmount = 5 * 10**6 * (10**18);
    uint256 public maxWalletLimit;
    uint256 public maxTxAmount;

    uint8 public liquidityFee = 5;
    uint8 public devFee = 3;
    uint8 public marketingFee = 2;
    uint16 internal totalFees = liquidityFee + devFee + marketingFee;

    address payable public _devWallet = payable(address(0xeB135a3beaeDf8e83B57a3A9C36d19aF37494Bd8));
    address payable public _marketingWallet = payable(address(0x6A53aac4FbC948A694F589c1BEb4B4b296cf73B2));

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 metisReceived,
        uint256 tokensIntoLiqudity
    );

    constructor() ERC20("Metis Moon", "MM") {

    	INetswapRouter02 _netswapRouter = INetswapRouter02(0x1E876cCe41B7b844FDe09E38Fa1cf00f213bFf56);

        address _netswapV2Pair = IUniswapV2Factory(_netswapRouter.factory())
            .createPair(address(this), _netswapRouter.Metis());

        netswapRouter = _netswapRouter;
        netswapV2Pair = _netswapV2Pair;

        _setAutomatedMarketMakerPair(_netswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1 * 10**9 * (10**18));
        maxWalletLimit = totalSupply().mul(2).div(100);
        maxTxAmount = totalSupply().mul(5).div(1000);
    }

    receive() external payable {}

    function updateRouter(address newAddress) public onlyOwner {
        require(newAddress != address(netswapRouter), "MM: The router already has that address");
        emit UpdateRouter(newAddress, address(netswapRouter));
        netswapRouter = INetswapRouter02(newAddress);
        address _netswapV2Pair = IUniswapV2Factory(netswapRouter.factory())
            .createPair(address(this), netswapRouter.Metis());
        netswapV2Pair = _netswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "MM: Account is already excluded");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setDevWallet(address payable wallet) external onlyOwner{
        _devWallet = wallet;
    }

    function setMarketingWallet(address payable wallet) external onlyOwner{
        _marketingWallet = wallet;
    }

    function setSwapAtAmount(uint256 value) external onlyOwner {
        swapTokensAtAmount = value;
    }

    function setMaxWalletAmount(uint256 value) external onlyOwner {
        maxWalletLimit = value;
    }

    function setMaxTxAmount(uint256 value) external onlyOwner {
        maxTxAmount = value;
    }

    function setLiquidityFee(uint8 value) external onlyOwner{
        liquidityFee = value;
        totalFees = liquidityFee + devFee + marketingFee;
    }

    function setdevFee(uint8 value) external onlyOwner{
        devFee = value;
        totalFees = liquidityFee + devFee + marketingFee;

    }

    function setmarketingFee(uint8 value) external onlyOwner{
        marketingFee = value;
        totalFees = liquidityFee + devFee + marketingFee;

    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != netswapV2Pair, "MM: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
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

            contractTokenBalance = swapTokensAtAmount;

            uint256 feeTokens = contractTokenBalance.mul(devFee+marketingFee).div(totalFees);
            swapAndSendToFee(feeTokens);

            uint256 swapTokens = contractTokenBalance.mul(liquidityFee).div(totalFees);
            swapAndLiquify(swapTokens);

            swapping = false;
        }


        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {
            require(amount <= maxTxAmount,"Transfer amount exceeds limit");
            if(!automatedMarketMakerPairs[to]){
                require(amount + balanceOf(to) <= maxWalletLimit,"Wallet limit reached");
            }
        	uint256 fees = amount.mul(totalFees).div(100);

        	amount = amount.sub(fees);

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

    function claimStuckTokens(address _token) external onlyOwner {
        require(_token != address(this),"No rug pulls");

        if (_token == address(0x0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function swapAndSendToFee(uint256 tokens) private  {

        uint256 initialBalance = address(this).balance;
        swapTokensForMetis(tokens);
        uint256 newBalance = address(this).balance.sub(initialBalance);

        uint256 fordev = newBalance.mul(devFee).div(devFee+marketingFee);

        _devWallet.transfer(fordev);
        _marketingWallet.transfer(newBalance - fordev);
    }

    function swapAndLiquify(uint256 tokens) private {
       // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current METIS balance.
        // this is so that we can capture exactly the amount of METIS that the
        // swap creates, and not make the liquidity event include any METIS that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for METIS
        swapTokensForMetis(half); // <- this breaks the METIS -> HATE swap when swap+liquify is triggered

        // how much METIS did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to netswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }


    function swapTokensForMetis(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = netswapRouter.Metis();

        _approve(address(this), address(netswapRouter), tokenAmount);

        // make the swap
        netswapRouter.swapExactTokensForMetisSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );

    }

    function addLiquidity(uint256 tokenAmount, uint256 metisAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(netswapRouter), tokenAmount);

        // add the liquidity
        netswapRouter.addLiquidityMetis{value: metisAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );

    }
}