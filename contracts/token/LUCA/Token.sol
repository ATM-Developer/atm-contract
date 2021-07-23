// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../../common/interface/IERC20.sol";
import "../../common/library/SafeMath.sol";
import "./Storage.sol";

contract Token is Storage, IERC20{
    using SafeMath for uint256;
    
    //IERC20 
    function totalSupply() override external view returns (uint256){
        return _totalSupply;
    }

    function transfer(address to, uint256 value) override external returns (bool) {
        _transferFragment(msg.sender, to, _lucaToFragment(value));
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) override external returns (bool){
        uint256 fragmentValue = _lucaToFragment(value);
        allowedFragments[from][msg.sender] = allowedFragments[from][msg.sender].sub(fragmentValue);
        _transferFragment(from, to, fragmentValue);
        emit Transfer(from, to, value);
        return true;
    }

    function balanceOf(address who) override external view returns (uint256){
        return _fragmentToLuca(fragmentBalances[who]);
    }

    function allowance(address owner_, address spender) override external view returns (uint256){
        return _fragmentToLuca(allowedFragments[owner_][spender]);
    }

    function approve(address spender, uint256 value) override external returns (bool){
        uint256 fragmentValue = _lucaToFragment(value);
        allowedFragments[msg.sender][spender] = fragmentValue;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    
    //internal 
    function _mint(address to, uint256 amount) internal {
            _totalSupply = _totalSupply.add(amount);
            uint256 scaledAmount = _lucaToFragment(amount);
            fragment = fragment.add(scaledAmount);
            require(scalingFactor <= _maxScalingFactor(), "LUCA: max scaling factor too low");
            fragmentBalances[to] = fragmentBalances[to].add(scaledAmount);
            emit Transfer(address(0), to, scaledAmount);
    }
   
    function _burn(address user, uint256 amount) internal {
            _totalSupply = _totalSupply.sub(amount);
            uint256 scaledAmount = _lucaToFragment(amount);
            fragment = fragment.sub(scaledAmount);
            fragmentBalances[user] = fragmentBalances[user].sub(scaledAmount);
            emit Transfer(user ,address(0), scaledAmount);
    }
    
    function _transferFragment(address from, address to, uint256 value ) internal {
        fragmentBalances[from] = fragmentBalances[from].sub(value);
        fragmentBalances[to] = fragmentBalances[to].add(value);
    }
    
    function _maxScalingFactor() internal view returns (uint256){
       return (type(uint256).max).div(fragment);
    }

    function _fragmentToLuca(uint256 value) internal view returns(uint256){ 
         return value.mul(scalingFactor).div(Decimals);
    }

    function _lucaToFragment(uint value) internal view returns (uint256){
        return value.mul(Decimals).div(scalingFactor);
    }
}
