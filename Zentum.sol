// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

interface IERC20Errors {
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

interface IUniswapV2Router {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
function swapExactTokensForTokens(
  uint amountIn,
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function token0() external view returns (address);

    function token1() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract Tentiumusdt is Context, IERC20, IERC20Metadata, IERC20Errors {
    IUniswapV2Router public router;
    IUniswapV2Pair public pair; // Pair information fetched during addInitialLiquidity
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;//0x3187e498d8b2aeb5c597D5d4222C4737016F0eED; //0x55d398326f99059fF775485246999027B3197955; // USDT on BSC mainnet
    address factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;//0x6725F303b657a9451d8BA641348b6761A6CC7a17; //0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // PancakeSwap Factory on BSC mainnet
    uint256 public constant TARGET_PRICE = 10**18; // $1 in 18 decimals
    bool public tradeStarted = false; // Tracks whether trading has started
    string public condition;
    uint256 public tolerance = 0;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    address public owner;

    constructor() {
        _name = "Zentum";
        _symbol = "USD.Z";
        owner = msg.sender;
        router = IUniswapV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);//(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); //0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap V2 Router on BSC mainnet
        address _uniswapV2Pair = IUniswapV2Factory(factory).createPair(
            address(this),
            usdt
        );
        _mint(msg.sender, 100000000000 * (10**18));
        pair = IUniswapV2Pair(_uniswapV2Pair);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not authorized");
        _;
    }

    function setTolerace(uint _new) public onlyOwner {
        tolerance = _new;
    }

    function startTrade() public onlyOwner {
        tradeStarted = true;
    }

    function stopTrade() public onlyOwner {
        tradeStarted = false;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address _owner = _msgSender();
        _transfer(_owner, to, value);
        return true;
    }

    function allowance(address _owner, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool)
    {
        address _owner = _msgSender();
        _approve(_owner, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    address public sender;
    address public recipient;

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        sender = from;
        recipient = to;
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);

        // if (tradeStarted && (from == address(pair) || to == address(pair))) {
        //     condition = "condition 1 called";
        //     _performCounterSwap(value);
        // }
    }

    uint256 public price;
    uint256 public deviation;
    uint256 public tokenToAdd;
    uint256 public usdtToAdd;
    uint256 public totalLiquidity;
    uint256 public liquidityToRemove;

    function _performCounterSwap(
        // address _sender,
        // address _recipient,
        uint256 amount
    ) internal {
        tradeStarted = false;
        condition = "condition 2 called";
        uint256 currentPrice = _getPrice();



        

        if (currentPrice > TARGET_PRICE ) {
            // Price is above target: Sell tokenA for tokenB
            uint256 sellAmount = _calculateSwapAmount(
                amount,
                currentPrice,
                "SELL"
            );
            
            _swap(address(this), usdt, sellAmount, address(this));
        } else if (currentPrice < TARGET_PRICE ) {
            // Price is below target: Buy tokenA with tokenB
            uint256 buyAmount = _calculateSwapAmount(
                amount,
                currentPrice,
                "BUY"
            );
            _swap(usdt, address(this), buyAmount, address(this));
        }

        tradeStarted = true;
    }

    /**
     * @notice Perform the token swap via the swap router.
     */
    function _swap(
        address fromToken,
        address toToken,
        uint256 amount,
        address _recipient
    ) public {
         condition = "condition 3 called";
        require(amount > 0, "Swap amount must be greater than 0");

        // Approve router to spend tokens
        IERC20(fromToken).approve(address(router), amount);

        address[] memory path;
        path[0] = fromToken;
        path[1] = toToken;

        uint256 deadline = block.timestamp + 300; // 5 minutes deadline

        router.swapExactTokensForTokens(
            amount,
            1, // Minimum amount out
            path,
            _recipient,
            deadline
        );
    }

    /**
     * @notice Get the current price of the token.
     */
    function _getPrice() internal pure returns (uint256) {
        // Placeholder: Replace with logic to fetch price from an oracle or AMM
        return TARGET_PRICE;
    }

    /**
     * @notice Calculate the amount for the swap based on the deviation.
     */
    function _calculateSwapAmount(
        uint256 transferAmount,
        uint256 currentPrice,
        string memory direction
    ) internal pure returns (uint256) {
        uint256 _deviation;

        if (
            keccak256(abi.encodePacked(direction)) ==
            keccak256(abi.encodePacked("SELL"))
        ) {
            _deviation = currentPrice - TARGET_PRICE;
        } else {
            _deviation = TARGET_PRICE - currentPrice;
        }

        // Scale the deviation by the transfer amount
        return (transferAmount * _deviation) / TARGET_PRICE;
    }

    /**
     * @notice Update the target price (owner only).
     */
   

    /**
     * @notice Update the tolerance (owner only).
     */
    function setTolerance(uint256 newTolerance) external onlyOwner {
        tolerance = newTolerance;
    }

    /**
     * @notice Update the swap router (owner only).
     */

    function rebalance(uint256 _tokenToAdd, uint256 _usdtToAdd) public {
        price = getPrice();

//        condition = "condition 2 called";
        if (price > TARGET_PRICE) {
            // Price above $1, add liquidity
            deviation = price - TARGET_PRICE;
            bool addL = addLiquidity(deviation, _tokenToAdd, _usdtToAdd);
            require(addL, "addLiquidity not working");
        } else if (price < TARGET_PRICE) {
            // Price below $1, remove liquidity
            deviation = TARGET_PRICE - price;
            bool addL = removeLiquidity(deviation, 0);
            require(addL, "removeLiquidity not working");
        }
    }

    function getPrice() public view returns (uint256 _price) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        require(reserve0 > 0, "Reserve0 is zero"); // Prevent division by zero
        if (pair.token0() == usdt) {
            _price = (uint256(reserve0) * (10**18)) / uint256(reserve1);
        } else {
            _price = (uint256(reserve1) * (10**18)) / uint256(reserve0);
        }
    }

    function addLiquidity(
        uint256 _deviation,
        uint256 _tokenToAdd,
        uint256 _usdtToAdd
    ) public returns (bool) {
        tradeStarted = false;
        // condition = "condition 3 called";
        // (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        // uint256 tokenReserve = pair.token0() == address(this)
        //     ? reserve0
        //     : reserve1;
        // uint256 usdtReserve = pair.token0() == usdt ? reserve0 : reserve1;

        // tokenToAdd = (tokenReserve * _deviation) / TARGET_PRICE;
        // usdtToAdd = (usdtReserve * _deviation) / TARGET_PRICE;

        IERC20(address(this)).approve(address(router), _tokenToAdd);
        IERC20(usdt).approve(address(router), _usdtToAdd);

        //try
        router.addLiquidity(
            address(this),
            usdt,
            _tokenToAdd,
            _usdtToAdd,
            1, // Minimum token amount (slippage)
            1, // Minimum USDT amount (slippage)
            address(this),
            block.timestamp + 300
        ); //{} catch {}

        tradeStarted = true;

        return true;
    }

    function removeLiquidity(uint256 _deviation, uint256 _liquidityToRemove)
        public
        returns (bool)
    {
        // Ensure sufficient liquidity tokens are held by the contract
        uint256 contractLiquidityBalance = IUniswapV2Pair(pair).balanceOf(
            address(this)
        );
        require(
            _liquidityToRemove <= contractLiquidityBalance,
            "Not enough liquidity tokens"
        );

        // Approve the router to use LP tokens (if not already approved)
        IUniswapV2Pair(pair).approve(address(router), _liquidityToRemove);

        // Temporarily disable trading
        tradeStarted = false;

        try
            router.removeLiquidity(
                address(this),
                usdt,
                _liquidityToRemove,
                1, // Minimum token amount
                1, // Minimum USDT amount
                address(this),
                block.timestamp + 300
            )
        {
            // Re-enable trading only if successful
            tradeStarted = true;
            return true;
        } catch {
            // Handle errors gracefully
            tradeStarted = false;
            revert("Liquidity removal failed");
        }
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(
        address _owner,
        address spender,
        uint256 value
    ) internal {
        _approve(_owner, spender, value, true);
    }

    function _approve(
        address _owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[_owner][spender] = value;
        if (emitEvent) {
            emit Approval(_owner, spender, value);
        }
    }

    function _spendAllowance(
        address _owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(_owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(_owner, spender, currentAllowance - value, false);
            }
        }
    }
}
