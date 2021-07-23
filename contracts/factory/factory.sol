// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/library/SafeMath.sol";
import "../common/interface/IERC20.sol";
import {Itrader} from "../trader/Itrader.sol";
import {Ifactory, ERC20_Token, IWETH} from "./Ifactory.sol";
import {Link} from "../link/link.sol";

contract Initialize {
    bool internal initialized;
    modifier noInit(){
        require(!initialized, "initialized");
        _;
        initialized = true;
    }
}

contract FactoryStorage is Initialize {
    bool    internal risk;     
    address internal luca;
    address internal wluca;
    address internal weth;
    address internal trader;
    address internal collector;
    address internal pledger;
    address internal ETH;
    
    address public owner;
    uint256 public totalLink;
   
    mapping(address => bool) internal linkMap;
    mapping(string => tokenConfig) internal tokenMap;
    
    struct tokenConfig {
        address addr;       
        uint256 minAmount;   
        bool    isActive;    
    }
}

contract Factory is Ifactory, FactoryStorage{
    using SafeMath for uint256;
    uint256 constant MIN_LOCK_DAYS = 1;   
    uint256 constant MAX_LOCK_DAYS = 1825;
    
    // valid user is owner
    modifier checkRisk() {
        require(!risk, "Factory: Danger!");
        _;
    }
    
    // valid user is owner
    modifier onlyOwner() {
        require(msg.sender == owner,'Factory: only owner');
        _;
    }
    
    // valid percentlimt is range of 1-100
    modifier validPercent(uint256 _percent) {
        require(_percent>=1 && _percent<=100,'Factory: percent need between 1 and 100');
        _;
    }

    // valid lockdays is range of 1-1825
    modifier validLockDays(uint256 _lockTime) {
        require(_lockTime>=MIN_LOCK_DAYS && _lockTime <= MAX_LOCK_DAYS,'Factory:  locktime need between 1 and 1825');
        _;
    }
    
    modifier validConfig(string memory _tokenSymbol, uint256 _amount, uint256 _percent) {
        tokenConfig memory config = tokenMap[_tokenSymbol];
        require(config.isActive, 'Factory: not allowed token');
        require(_amount.mul(_percent).div(100) >= config.minAmount,'Factory: lock amount too small');
        _;
    }
    
    function initialize(address _luca, address _wluca, address _trader, address _weth, address _collector, address _pledger) external noInit{
       owner = msg.sender;
       luca = _luca;
       wluca = _wluca;
       weth =_weth;
       trader = _trader;
       collector = _collector;
       pledger = _pledger;
       ETH = address(0);
       
       _addTokenMap("LUCA", _luca, 1);
       _addTokenMap("ETH", ETH, 1);
    }
    
    function setOwner(address _user)  override external onlyOwner {
        owner = _user;
    }
    
    function setPledger(address _user)  override external onlyOwner {
        pledger = _user;
    }
    
    function setCollector(address _user) override external onlyOwner {
        collector = _user;
    }
    
    function getCollector() override external view returns(address){
        return collector;
    }
    
    function setRisk() external override onlyOwner {
        risk = !risk;
    }
    
    function isLink(address _link) override external view returns(bool){
        return linkMap[_link];
    }
    
    function isAllowedToken(string memory _symbol, address _addr) override external view returns(bool) {
        if (tokenMap[_symbol].addr == _addr){
            return true;
        }
        return false;
    }
    
    function addToken(address _tokenAddr, uint256 _minAmount) override external onlyOwner {
       string memory tokenSymbol = ERC20_Token(_tokenAddr).symbol();
       require(bytes(tokenSymbol).length >= 0 , "Factory: not available Token");
       require(!tokenMap[tokenSymbol].isActive, "Factory: token exist" );
       _addTokenMap(tokenSymbol, _tokenAddr, _minAmount);
    }
    
    function _addTokenMap(string memory _symbol, address _tokenAddr, uint256 _minAmount) internal {
       tokenConfig memory tf;
       tf.addr = _tokenAddr;
       tf.minAmount = _minAmount;
       tf.isActive = true;
       tokenMap[_symbol]=tf;
    }
    
    
    function updateTokenConfig(string  memory _symbol, address _tokenAddr, uint256 _minAmount) override external onlyOwner {
         require(tokenMap[_symbol].isActive, "Factory: token not exist" );
         tokenConfig memory tf;
         tf.addr = _tokenAddr;
         tf.minAmount = _minAmount;
         tf.isActive = true;
         tokenMap[_symbol]=tf;
         emit UpdatetokenConfig( _symbol, _tokenAddr, _minAmount);
    }
    
    function createLink(address _userB, string memory _symbol, uint256 _tatalPlan, uint256 _percentA, uint256 _lockDays) payable override external
        validPercent(_percentA)
        validLockDays(_lockDays)
        checkRisk()
        returns(address)
        {   
            require(_userB != msg.sender, "Factory: to account is self.");
            tokenConfig memory config = tokenMap[_symbol];
            require(config.isActive, "Factory: token not exist");
            require(_tatalPlan.mul(_percentA).div(100) >= config.minAmount, "Factory: amount too small");
            uint256 amountA = _tatalPlan.mul(_percentA).div(100);
            Link link = _createLink();
            if (config.addr == ETH){
                require(msg.value >= amountA, "not enough ETH");
                IWETH(weth).deposit{value: msg.value}();
                IWETH(weth).transfer(address(link), msg.value);
            }else{
                //payment and linitualize
                Itrader(trader).payment(config.addr, msg.sender, address(link), amountA);
            }
            
            link.initialize(msg.sender, _userB, config.addr, _symbol, _tatalPlan, _percentA, _lockDays);
            emit LinkCreated(msg.sender, _symbol, address(link));
            return address(link);
    }
    
    function _createLink() internal returns(Link){
         Link link = new Link(address(this), luca, wluca, trader, weth, pledger);
         totalLink++;
         linkMap[address(link)] = true;
         return link;
    }
}