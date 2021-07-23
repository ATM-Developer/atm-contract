// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../common/interface/IERC20.sol";
import "../common/library/SafeMath.sol";
import "../token/WLUCA/IWluca.sol";
import "../factory/Ifactory.sol";
import "./Itrader.sol";

contract Initialize {
    bool private initialized;
    modifier noInit(){
        require(!initialized, "initialized");
        _;
        initialized = true;
    }
}

contract Storage is Initialize {
    address     public owner;
    address     public wluca;
    address     public luca;
    address     public factory;
    address[]   public whiteList;
}

contract Trader is Storage, Itrader{
    modifier onlyOwner(){
        require(msg.sender == owner, "Trader: access denied");
        _;
    }
    
    modifier verifyCaller(){
        require(msg.sender == factory || Ifactory(factory).isLink(msg.sender) || _isInWhiteList() , "Trader: access denied");
        _;
    }
    
    modifier verifyAllowed(address _token, address _from, uint256 amount){
        require(IERC20(_token).allowance(_from, address(this)) >= amount, "Trader: not enough allowed token");
        _;
    }
    
    function initialize(address _luca, address _wluca, address _factory) external noInit {
        wluca = _wluca;
        luca = _luca;
        factory = _factory;
        owner = msg.sender;
    }
    
    function balance() override external view returns(uint256 luca_balance, uint256 wluca_supply){
        return (IERC20(luca).balanceOf(address(this)), IERC20(wluca).totalSupply());
    }
    
    function deposit(uint256 _amount) override external verifyCaller returns(bool) {
        require(IERC20(luca).transferFrom(msg.sender, address(this), _amount), "Trader:  not enough allowed luca");
        Iwluca(wluca).mint(msg.sender, _amount);
        return true;
    }
    
    function withdraw(uint256 _amount) override external verifyCaller returns(bool) {
        require(IERC20(wluca).transferFrom(msg.sender, address(this), _amount), "Trader: not enough allowed wluca");
        Iwluca(wluca).burn(_amount);
        IERC20(luca).transfer(msg.sender, _amount);
        return true;
    }
    
    
    //use for factory
    function payment(address _token, address _from, address _to, uint256 _amount) override external  verifyCaller  verifyAllowed(_token, _from, _amount)returns(bool){
        if (_token == luca) {
            IERC20(luca).transferFrom(_from, address(this), _amount);
            Iwluca(wluca).mint(_to, _amount);
            return true;
        } 
        
        return IERC20(_token).transferFrom(_from, _to, _amount);
    }
    
    //use for link
    function withdrawFor(address _to, uint256 _amount) override external verifyCaller {
        require(IERC20(wluca).transferFrom(msg.sender, address(this), _amount), "Trader: not enough allowed wluca");
        Iwluca(wluca).burn(_amount);
        IERC20(luca).transfer(_to, _amount);
    }
    
    
    function addWhiteList(address _addr) override external {
        require(msg.sender == owner,"Trader: onlyOwner");
        whiteList.push(_addr);
    }
    
    function setFactory(address _factory) override external onlyOwner{
        factory = _factory;
    }
    
    
    function _isInWhiteList() internal view returns(bool){
        for (uint i = 0; i < whiteList.length; ++i){
             if (msg.sender == whiteList[i]) return true;
        }
        
        return false;
    }

}




