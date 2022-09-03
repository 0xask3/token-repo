// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract BridgeTokenBsc is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1 * 10**11 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Bridge Token";
    string private _symbol = "BDGK";
    uint8 private _decimals = 9;

    struct TradeFee {
        uint16 liquidityFee;
        uint16 charityFee;
        uint16 buybackFee;
        uint16 taxFee;
        uint16 useFee;
    }

    struct TransferFee {
        uint16 liquidityFee;
        uint16 charityFee;
        uint16 buybackFee;
        uint16 taxFee;
    }

    TradeFee public tradeFee;
    TransferFee public transferFee;

    uint16 private _taxFee;
    uint16 private _liquidityFee;
    uint16 private _charityFee;
    uint16 private _buybackFee;
    uint16 private _useFee;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address public _charityWallet = payable(address(0x123));
    address public _useWallet = payable(address(0x456));

    bool internal inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public isTradingEnabled;
    uint256 public tradingStartBlock;

    uint8 public constant BLOCKCOUNT = 25; //Blacklist first 25 block buys
    uint256 private constant MAXGAS = 200 gwei; //Maximum gas price

    uint256 public _maxTxAmount = 1 * 10**9 * 10**9;
    uint256 private numTokensSellToAddToLiquidity = 1 * 10**7 * 10**9;
    uint256 public buybackLimit = 0.1 ether;

    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => bool) public _isBlackListed;

    mapping(address => uint256) private lastBlock;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        tradeFee.liquidityFee = 300;
        tradeFee.charityFee = 200;
        tradeFee.buybackFee = 100;
        tradeFee.taxFee = 500;
        tradeFee.useFee = 200;

        transferFee.liquidityFee = 100;
        transferFee.charityFee = 100;
        transferFee.buybackFee = 100;
        transferFee.taxFee = 100;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        );
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(0xdead)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromBuyback(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromBuyback(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInBuyback(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function setLimitForWallet(address account, bool val) external onlyOwner {
        _isExcludedFromLimits[account] = val;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function removeBlackList(address addr) external onlyOwner {
        _isBlackListed[addr] = false;
    }

    function enableTrading() external onlyOwner {
        isTradingEnabled = true;
        tradingStartBlock = block.number;
    }

    function setTradeFee(
        uint16 liq,
        uint16 market,
        uint16 buyback,
        uint16 tax,
        uint16 use
    ) external onlyOwner {
        tradeFee.liquidityFee = liq;
        tradeFee.charityFee = market;
        tradeFee.buybackFee = buyback;
        tradeFee.taxFee = tax;
        tradeFee.useFee = use;
    }

    function setTransferFee(
        uint16 liq,
        uint16 market,
        uint16 buyback,
        uint16 tax
    ) external onlyOwner {
        transferFee.liquidityFee = liq;
        transferFee.charityFee = market;
        transferFee.buybackFee = buyback;
        transferFee.taxFee = tax;
    }

    function setNumTokensSellToAddToLiquidity(uint256 numTokens)
        external
        onlyOwner
    {
        numTokensSellToAddToLiquidity = numTokens;
    }

    function updateRouter(address newAddress) external onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "TOKEN: The router already has that address"
        );
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function setMaxTx(uint256 maxTx) external onlyOwner {
        _maxTxAmount = maxTx;
    }

    function setBuyBackLimit(uint256 value) external onlyOwner {
        buybackLimit = value;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function claimStuckTokens(address _token) external onlyOwner {
        require(_token != address(this), "No rug pulls :)");

        if (_token == address(0x0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IERC20 erc20token = IERC20(_token);
        uint256 balance = erc20token.balanceOf(address(this));
        erc20token.transfer(owner(), balance);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {
        this;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tBuyback,
            uint256 tWallet
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            tBuyback,
            tWallet,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tBuyback = calculateBuybackFee(tAmount);
        uint256 tWallet = calculateCharityFee(tAmount) +
            calculateUseFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        tTransferAmount = tTransferAmount.sub(tBuyback).sub(tWallet);
        return (tTransferAmount, tFee, tLiquidity, tBuyback, tWallet);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tBuyback,
        uint256 tWallet,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rBuyback = tBuyback.mul(currentRate);
        uint256 rWallet = tWallet.mul(currentRate);
        uint256 rTransferAmount = rAmount
            .sub(rFee)
            .sub(rLiquidity)
            .sub(rBuyback)
            .sub(rWallet);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _takeUse(uint256 tUse) private {
        uint256 currentRate = _getRate();
        uint256 rUse = tUse.mul(currentRate);
        _rOwned[_useWallet] = _rOwned[_useWallet].add(rUse);
        if (_isExcluded[_useWallet])
            _tOwned[_useWallet] = _tOwned[_useWallet].add(tUse);
        if (tUse > 0) {
            emit Transfer(msg.sender, _useWallet, tUse);
        }
    }

    function _takeBuybackAndCharity(uint256 tBuyback, uint256 tCharity)
        private
    {
        uint256 currentRate = _getRate();
        uint256 rBuyback = tBuyback.mul(currentRate);
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rCharity).add(
            rBuyback
        );

        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tCharity).add(
                tBuyback
            );
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**4);
    }

    function calculateUseFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_useFee).div(10**4);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**4);
    }

    function calculateBuybackFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_buybackFee).div(10**4);
    }

    function calculateCharityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_charityFee).div(10**4);
    }

    function removeAllFee() private {
        _taxFee = 0;
        _liquidityFee = 0;
        _buybackFee = 0;
        _charityFee = 0;
        _useFee = 0;
    }

    function setTrade() private {
        _taxFee = tradeFee.taxFee;
        _liquidityFee = tradeFee.liquidityFee;
        _buybackFee = tradeFee.buybackFee;
        _charityFee = tradeFee.charityFee;
        _useFee = tradeFee.useFee;
    }

    function setTransfer() private {
        _taxFee = transferFee.taxFee;
        _liquidityFee = transferFee.liquidityFee;
        _buybackFee = transferFee.buybackFee;
        _charityFee = transferFee.charityFee;
        _useFee = 0;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            !_isBlackListed[from] && !_isBlackListed[to],
            "Account is blacklisted"
        );
        require(tx.gasprice <= MAXGAS, "Gas amount exceeds limit");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (!inSwapAndLiquify && from != uniswapV2Pair) {
            uint256 balance = address(this).balance;
            if (balance > buybackLimit) {
                swapETHForTokens(buybackLimit.div(10));
            }
        }

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;

            uint256 forLiquidity = contractTokenBalance
                .mul(tradeFee.liquidityFee + transferFee.liquidityFee)
                .div(
                    tradeFee.charityFee +
                        transferFee.charityFee +
                        tradeFee.liquidityFee +
                        transferFee.liquidityFee +
                        tradeFee.buybackFee +
                        transferFee.buybackFee
                );

            swapAndSendFee(contractTokenBalance - forLiquidity);

            swapAndLiquify(forLiquidity);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, buyback, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapAndSendFee(uint256 amount) private lockTheSwap {
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(amount);
        uint256 newBalance = address(this).balance.sub(initialBalance);

        uint256 forCharity = newBalance
            .mul(tradeFee.charityFee + transferFee.charityFee)
            .div(
                tradeFee.charityFee +
                    transferFee.charityFee +
                    tradeFee.buybackFee +
                    transferFee.buybackFee
            );

        payable(_charityWallet).transfer(forCharity);
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

    function swapETHForTokens(uint256 amount) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(
            0, // accept any amount of Tokens
            path,
            address(0xdead), // Burn address
            block.timestamp.add(300)
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
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        removeAllFee();

        if (takeFee) {
            require(isTradingEnabled, "Trading not enabled yet");

            require(lastBlock[tx.origin] < block.number, "Wait for some time");

            lastBlock[tx.origin] = block.number;

            if (
                !_isExcludedFromLimits[sender] &&
                !_isExcludedFromLimits[recipient]
            ) {
                require(
                    amount <= _maxTxAmount,
                    "Transfer amount exceeds the maxTxAmount."
                );
            }
            if (sender == uniswapV2Pair || recipient == uniswapV2Pair) {
                if (
                    sender == uniswapV2Pair &&
                    block.number < tradingStartBlock + BLOCKCOUNT
                ) {
                    _isBlackListed[recipient] = true;
                }
                setTrade();
            } else {
                setTransfer();
            }
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBuybackAndCharity(
            calculateBuybackFee(tAmount),
            calculateCharityFee(tAmount)
        );
        _takeUse(calculateUseFee(tAmount));
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBuybackAndCharity(
            calculateBuybackFee(tAmount),
            calculateCharityFee(tAmount)
        );
        _takeUse(calculateUseFee(tAmount));
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBuybackAndCharity(
            calculateBuybackFee(tAmount),
            calculateCharityFee(tAmount)
        );
        _takeUse(calculateUseFee(tAmount));
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBuybackAndCharity(
            calculateBuybackFee(tAmount),
            calculateCharityFee(tAmount)
        );
        _takeUse(calculateUseFee(tAmount));
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
