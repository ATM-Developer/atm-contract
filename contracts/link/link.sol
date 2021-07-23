// SPDX-License-Identifier: MIT

pragma solidity ^ 0.8.0;
import "../common/interface/IERC20.sol";
import "../common/library/SafeMath.sol";
import {Ifactory, IWETH} from "../factory/Ifactory.sol";
import {Itrader} from "../trader/Itrader.sol";
import {Ilink, Ipledger} from "./Ilink.sol";

contract Initialized {
    bool internal initialized;
    
    modifier noInit(){
        require(!initialized, "initialized");
        _;
        initialized = true;
    }
}

contract Enum {
    Status internal status;
    enum Status {
        INITED,
        AGREED,
        CLOSED,
        PLEDGED
    }

    function _init() internal {
        status = Status.INITED;
    }

    function _agree() internal {
        status = Status.AGREED;
    }

    function _close() internal {
        status = Status.CLOSED;
    }
    
    function _pledge() internal {
        status = Status.PLEDGED;
    }
}

contract LinkInfo is Enum {
    address internal factory;
    address internal luca;
    address internal wluca;
    address internal trader;
    address internal collector;
    address internal pledger;
    address internal weth;
    address internal ETH;
    bool    internal closeReqA;
    bool    internal closeReqB;
    bool    internal pledgedA;
    bool    internal pledgedB;
    
    string   symbol;
    address  userA;
    address  userB;
    uint256  amountA;
    uint256  amountB;
    uint256  percentA;
    uint256  totalPlan;
    address  token;
    address  closer;
    uint256  lockDays;
    uint256  startTime;
    uint256  expiredTime;
    uint256  closeTime;

    uint256  receivableA;
    uint256  receivableB;
    bool     isExitA;
    bool     isExitB;
    
    
    modifier onlyLuca(){
        require(token == luca, "Link: only luca");
        _;
    }
    
    modifier onlyFactory(){
        require(msg.sender == factory, "Link: only factory");
        _;
    }

    modifier onlyEditLink(){
        require(msg.sender == userA, "Link: only userA");
        require(userB == address(0) && percentA == 100, "Link: only Editable Link");
        _;
    }

    modifier onlyLinkUser(){
        require(msg.sender == userA || msg.sender == userB, "Link: access denied");
        _;
    }

    modifier onlyUserB(){
        require(msg.sender == userB, "Link: noly userB");
        _;
    }

    modifier onlyINITED(){
        require(status == Status.INITED, "Link: only initialized");
        _;
    }

    modifier onlyAGREED(){
        require(status == Status.AGREED, "Link: only agreed");
        _;
    }

    modifier onlyCLOSED(){
        require(status == Status.CLOSED, "Link: olny closed");
        _;
    }

    modifier unCLOSED(){
        require(status != Status.CLOSED, "Link: only unclosed");
        _;
    }
    
    modifier onlyPLEDGED(){
        require(status == Status.PLEDGED, "Link: only pledged");
        _;
    }
    
    modifier unPLEDGED(){
        require(status != Status.PLEDGED, "Link: only unpledged");
        _;
    }
}

contract Link is LinkInfo, Initialized, Ilink {
    using SafeMath for uint256;
    
    constructor(address _factory, address _luca, address _wluca, address _trader, address _weth, address _pledger){
        factory = _factory;
        luca = _luca;
        wluca = _wluca;
        trader = _trader;
        pledger = _pledger;
        weth = _weth;
        ETH = address(0);
    }
    
    
    //Link build
    function verifyDeposit(address _token, address _user) internal view returns(bool){
        uint256 amount;
        if (_token == ETH){
            amount = IERC20(weth).balanceOf(address(this));
        }else if (_token == luca){
            amount = IERC20(wluca).balanceOf(address(this));
        }else{
            amount = IERC20(_token).balanceOf(address(this));
        }
        
        if (_user == userA) {
            if (amount == amountA) return true;
        }else{
            if (amount >= totalPlan) return true;
        }

        return false;
    }

    function initialize(address _userA, address _userB, address _token, string memory _symbol, uint256 _amount, uint256 _percentA, uint256 _lockDays) external onlyFactory noInit{
        require(verifyDeposit(_token, _userA), "Link: userA deposit not enough");
        {
            userA = _userA;
            userB = _userB;
            token = _token;
            symbol = _symbol;
            totalPlan = _amount;
            percentA = _percentA;
            amountA = _amount.mul(_percentA).div(100);
            amountB = _amount.sub(amountA);
            lockDays = _lockDays;
        }
        if(_percentA == 100 && userB != address(0)){
            startTime = block.timestamp;
            expiredTime = startTime.add(lockDays.mul(1 days));
            _agree();
        }else{
            _init();
        }
    }

    function setUserB(address _userB) override external onlyEditLink {
        require(_userB != address(0) && _userB != msg.sender, "Link: unlawful address");
        userB = _userB;
        startTime = block.timestamp;
        expiredTime = startTime.add(lockDays.mul(1 days));
        _agree();
    }

    function reject() override external onlyUserB onlyINITED{
        _exit();
    }

    function agree() override payable external onlyUserB onlyINITED{
        if (token == ETH){
            require(msg.value >= amountB, "not enough ETH");
            IWETH(weth).deposit{value: msg.value}();
            IWETH(weth).transfer(address(this), msg.value);
        }else{
            Itrader(trader).payment(token, userB, address(this), amountB);
        }
        
        require(verifyDeposit(token, userB), "Link: deposit not enough" );
        startTime = block.timestamp;
        expiredTime = startTime.add(lockDays.mul(1 days));
        _agree();
    }
    
    
    //pledge
    function pledge() override external onlyLuca onlyLinkUser {
        require(status == Status.PLEDGED || status == Status.AGREED, "Link: access denied");
        require(!isExpire(), "Link: cant pledge on expire ");
        
        uint256 amount;
        if (msg.sender == userA){
             require(!pledgedA, "Link: repledge");
             pledgedA = true;
             amount = amountA;
        }else{
             require(!pledgedB, "Link: repledge");
             pledgedB= true;
             amount = amountB;
        }
        
        _pledge();
        Ipledger(pledger).pledge(msg.sender, amount);
    }
    
    function depledge() override external onlyLuca onlyPLEDGED onlyLinkUser{
        if (msg.sender == userA){
             require(pledgedA, "Link: no pledged");
             pledgedA = false;
        }else{
             require(pledgedB, "Link: no pledged");
             pledgedB= false;
        }
        
        Ipledger(pledger).depledge(msg.sender);
        
        //other exited
        if (isExitA || isExitB){ 
            closer = msg.sender;
            closeTime = block.timestamp;
            _exitSelf();
            _close();
            return;
        }
        
        if (!pledgedA && !pledgedB) _agree();
        
    }
    
    function wtihdrawSelf() override external onlyLuca onlyPLEDGED onlyLinkUser{
         require(isExpire(),"Link: only Expire");
         _setReceivables(100);
         _exitSelf();
    }
    
    
    //Link renew
    function close() override external unCLOSED unPLEDGED onlyLinkUser {
        //Expire 
        if (isExpire()){
            _exit();
        }
        
        //INITED
        if (status == Status.INITED){
            require(msg.sender == userA,"Link: access denied");
            _exit();
        }

        //AGREED
        if (status == Status.AGREED){
            if (msg.sender == userA) {
                closeReqA = true;
            }else{
                closeReqB = true;
            }
            
            if (closeReqA && closeReqB){
                _exit();
            }
        }
    }
    
    function repealCloseReq() override external onlyAGREED onlyLinkUser { 
        if (msg.sender == userA) {
            closeReqA = false;
        }else{
            closeReqB = false;
        }
    }
    
    function rejectClose() override external onlyAGREED onlyLinkUser{
        if (msg.sender == userB) {
            closeReqA = false;
        }else{
            closeReqB = false;
        }
    }
    
    
    //Link query
    function isExpire() override public view returns(bool) {
        if (status == Status.INITED || expiredTime == 0){
            return false;
        }
        return (block.timestamp >= expiredTime);
    }
    
    function getPledgedInfo() override external view returns(bool pledgedA_, bool pledgedB_){
        return(pledgedA, pledgedB);
    }
    
    function getCloseInfo() override external view returns(address closer_, uint256 startTime_,uint256 expiredTime_,uint256 closeTime_, bool closeReqA_, bool closeReqB_){
        return(closer, startTime, expiredTime, closeTime, closeReqA, closeReqB);
    }

    function getStatus() override external view returns(string memory status_){
        if (Status.INITED == status)  return "initialized";
        if (Status.AGREED == status)  return "agreed";
        if (Status.PLEDGED == status) return "pledged";
        if (Status.CLOSED == status)  return "closed";
    }
    
    function getRecevabesInfo() override external view returns(uint256 receivableA_, bool isExitA_, uint256 receivableB_, bool isExitB_){
        return(receivableA, isExitA, receivableB, isExitB);
    }

    function getLinkInfo() override external view returns(string memory symbol_,address token_,address userA_, address userB_, uint256 amountA_, uint256 amountB_,uint256 percentA_,uint256 totalPlan_,uint256 lockDays_,uint256 startTime_,uint256 status_, bool isAward_){
        bool isAward;
        if ((status == Status.AGREED) || ((status == Status.PLEDGED) && (!isExitA && !isExitB))) {
            isAward = true;
        }
        
        return(symbol, token, userA, userB, amountA, amountB, percentA, totalPlan, lockDays, startTime, uint256(status), isAward);
    }
    
    function _exit() internal{
        closer = msg.sender;
        closeTime = block.timestamp;
        _liquidation();
        _close();
    }
    
    function _exitSelf() internal{
        if (msg.sender == userA){
            //userA unpledge and notExit
            require(!pledgedA && !isExitA, "Link: access denied ");
            isExitA = true;
            _withdraw(userA, receivableA);
        }else{
            //userB unpledge and notExit
            require(!pledgedB && !isExitB, "Link: access denied ");
            isExitB = true;
            _withdraw(userB, receivableB);
        }
    }

    function _liquidation() internal{
        if (status == Status.INITED || isExpire()) {
            _setReceivables(100);
        }else{//AGREED
            uint256 day = (closeTime.sub(startTime)).div(1 days);
            //dayFator = {(lockDays-day)/lockDays} * 0.2 *10^4
            uint256 dayFator = (lockDays.sub(day)).mul(1000*2).div(lockDays);
            if (day == 0) {
                _setReceivables(100-20);
            }else if(dayFator < 100){   //  <0.01
                _setReceivables(99);
            }else if(dayFator > 2000){  //  >0.2
                _setReceivables(80);
            }else{                      //  0.01 - 0.2
                _setReceivables(100-(dayFator.div(100)));
            }
            
            uint256 fee = totalPlan.sub(receivableA.add(receivableB));
            _withdraw(Ifactory(factory).getCollector(), fee);
        }
        
         isExitA = true;
         isExitB = true;
         _withdraw(userA, receivableA);
         if (receivableB > 0) _withdraw(userB, receivableB);
    }

    function _withdraw(address to, uint amount) internal{
        if (token == ETH){
             IWETH(weth).withdraw(amount);
             payable (to).transfer(amount);
        }else if(token == luca){
            IERC20(wluca).approve(trader, amount);
            Itrader(trader).withdrawFor(to, amount);
        }else{
            IERC20(token).transfer(to, amount);
        }
    }
    
    function _setReceivables(uint256 factor) internal{
        receivableA = amountA.mul(factor).div(100);

        if (status == Status.AGREED && amountB != 0){
            receivableB = amountB.mul(factor).div(100);
        }
    }
}