// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../../common/library/SafeMath.sol";
import "./ILuca.sol";
import "./Token.sol";

//support for poxry
contract Luca is Token, ILuca{
    using SafeMath for uint256;
    
    function initialize(string memory name, string memory symbol, uint256 totalSupply) public {
        _initialize(name, symbol, 18, totalSupply*10**18);
    }
    
    function setReceiver(address user) override external onlyOwner{
        receiver = user;
    }
    
    function setMinter(address user) override external onlyOwner{
        minter =  user;
    }
    
    function setRebaser(address user) override external onlyOwner{
        rebaser = user;
    }
    
    function rebaseByMilli(uint256 epoch, uint256 milli, bool positive) override external onlyRebaser returns (uint256){
        require(milli <= 1000, "LUCA: milli need less than 1000");
        return _rebase(epoch, milli.mul(BASE.div(1000)), positive);
    }
    
    function rebase(uint256 epoch, uint256 indexDelta, bool positive) override external onlyRebaser returns (uint256){
         return _rebase(epoch, indexDelta, positive);
    }
    
    function mint(uint256 amount) override external onlyMinter {
        _mint(receiver, amount);
    }
    
    function burn(uint256 amount) override external {
        _burn(msg.sender, amount);
    }
    
    function fragmentToLuca(uint256 value) override external view returns (uint256){
        return _fragmentToLuca(value);
    }
    
    function lucaToFragment(uint256 value) override external view returns (uint256){
      return _lucaToFragment(value);
    }
    
    function _rebase(uint256 epoch, uint256 indexDelta, bool positive) internal returns (uint256){
        emit Rebase(epoch, indexDelta, positive);
        if (indexDelta == 0)  return _totalSupply;
        
        if (!positive) {
            scalingFactor = scalingFactor.mul(BASE.sub(indexDelta)).div(BASE);
        } else {
            uint256 newScalingFactor = scalingFactor.mul(BASE.add(indexDelta)).div(BASE);
            if (newScalingFactor < _maxScalingFactor()) {
                scalingFactor = newScalingFactor;
            } else {
                scalingFactor = _maxScalingFactor();
            }
        }
        
        _totalSupply = _fragmentToLuca(fragment);
        return _totalSupply;
    }
    
    function _initialize(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initTotalSupply) internal noInit {
        scalingFactor = BASE;
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _totalSupply = _initTotalSupply;
        fragment = _lucaToFragment(_initTotalSupply);
        fragmentBalances[msg.sender] = fragment;
        rebaser = owner;
        minter = owner;
        receiver = owner;
    }
}

