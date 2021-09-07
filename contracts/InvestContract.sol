// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0 ;

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
}
interface UniswapRouterV2 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (
        uint amountA, 
        uint amountB, 
        uint liquidity
    );

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (
        uint256[] memory amounts
    );
}

interface UniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

contract Ownable is Initializable{
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init_unchained() internal initializer {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract  InvestContract is Initializable,Ownable{
    using SafeMath for uint256;
    IERC20 public UsdcToken;// 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;//mainnet   rinkeby
    uint256 public launchAmount = 5 * 10**18;//5000000 * 10**18;
    UniswapV2Factory public constant UNISWAP_FACTORY = UniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );
    UniswapRouterV2 public constant UNISWAP_ROUTER = UniswapRouterV2(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );
    IERC20 public lucaToken;
    IERC20 public lucaToUsdcPair;
    uint256 public investUsdcSum;
    uint256 public liquiditySum;
    uint256 public lockTime;
    uint256 public investTime;
    uint256 public launchTime;
    mapping(address => InvestMsg) public userInvestMsg;  
    event InvestLuca(address usrAddr, uint256 amount, uint256 timestamp);
    event WithdrawLiquidity(address usrAddr, uint256 liquidityAmount, uint256 timestamp);
    
    struct InvestMsg {
        uint256 amount;  
        uint256 mark; 
    }
    
    function init(address _lucaToken,address _usdc) external initializer{
        __Ownable_init_unchained();
        __Invest_init_unchained(_lucaToken,_usdc);
    }
    
    function __Invest_init_unchained(address _lucaToken,address _usdc) internal initializer{
        lucaToken = IERC20(_lucaToken);
        UsdcToken = IERC20(_usdc);
        lockTime = 20 days;
        investTime = 730 days;
        launchTime = block.timestamp;
    }
    
    receive() payable external{

    }
    
    fallback() payable external{

    }

    function  updateLucaToken(address _lucaToken) external onlyOwner{
        lucaToken = IERC20(_lucaToken);
    }
    
    function  updateInvestTime(uint256 _investTime) external onlyOwner{
        investTime = _investTime;
    }
    
    function  updateLaunchAmount(uint256 _launchAmount) external onlyOwner{
        launchAmount = _launchAmount;
    }
    
    function  updateLockTime(uint256 _lockTime) external onlyOwner{
        lockTime = _lockTime;
    }
    
    function  investLuca(uint256 _amount) external{
        uint256 endTime = launchTime + investTime;
        require(block.timestamp < endTime, "The time to invest is over");
        address _sender = msg.sender;
        require(UsdcToken.transferFrom(_sender,address(this),_amount), "Token transfer failed");
        investUsdcSum = investUsdcSum.add(_amount);
        userInvestMsg[_sender].amount = userInvestMsg[_sender].amount.add(_amount);
        emit InvestLuca(_sender, _amount, block.timestamp);
    }
    
   function  withdrawLiquidity() external returns(bool){
        address _sender = msg.sender;
        (uint256 _liquidityAmount,,) = calcLiquidity(_sender);
        require(_liquidityAmount > 0, "Users can withdraw liquidity to zero");
        userInvestMsg[_sender].mark = userInvestMsg[_sender].mark.add(_liquidityAmount);
        uint256 _LiquidityBalance = lucaToUsdcPair.balanceOf(address(this));
        require(_LiquidityBalance >= _liquidityAmount, "The contract transaction pair has insufficient liquidity");
        require(lucaToUsdcPair.transfer(_sender, _liquidityAmount), "Liquidity withdrawal failure");
        emit WithdrawLiquidity(_sender, _liquidityAmount, block.timestamp);
        return true;
    }
    
    
    function  forwardLiquidity() external {
        uint256 endTime = launchTime + investTime;
        require(block.timestamp > endTime, "Investment time is not over");
        uint256 _amount = investUsdcSum;
        UsdcToken.approve(address(UNISWAP_ROUTER), 2**256-1);
        lucaToken.approve(address(UNISWAP_ROUTER),  2**256-1);
        (,,liquiditySum) = UNISWAP_ROUTER.addLiquidity(
            address(UsdcToken),
            address(lucaToken),
            _amount,
            launchAmount,
            0,
            0,
            address(this),
            block.timestamp.add(2 hours)
        );
        lucaToUsdcPair = IERC20(UNISWAP_FACTORY.getPair(address(UsdcToken),address(lucaToken)));
    }
    
    function  queryInvestMsg(address _sender) external view returns(uint256,uint256,uint256){
        (uint256 _LiquidityAmount,uint256 _mark,uint256 _LiquiditySum) = calcLiquidity(_sender);
        return (_LiquidityAmount,_mark,_LiquiditySum);
    }
    
    function  calcLiquidity(address _sender) internal view returns(uint256, uint256, uint256){
        InvestMsg memory investMsg = userInvestMsg[_sender];
        uint256 _LiquiditySum = investMsg.amount.mul(liquiditySum).div(investUsdcSum);
        uint256 _startTime = launchTime + investTime;
        uint256 _liquidityAmount = 0;
        uint256 unitTime = lockTime.div(4);
        if(block.timestamp > _startTime.add(unitTime*4)){
            _liquidityAmount = _LiquiditySum;
        }else if(block.timestamp > _startTime.add(unitTime*3)){
            _liquidityAmount = _LiquiditySum.mul(3).div(4);
        }else if(block.timestamp > _startTime.add(unitTime*2)){
            _liquidityAmount = _LiquiditySum.div(2);
        }else if(block.timestamp > _startTime.add(unitTime)){
            _liquidityAmount = _LiquiditySum.mul(1).div(4);
        }
        _liquidityAmount = _liquidityAmount.sub(investMsg.mark);
        return (_liquidityAmount, investMsg.mark, _LiquiditySum);
    }
    
}
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
