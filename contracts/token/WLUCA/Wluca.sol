// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./IWluca.sol";

contract WLUCA is ERC20, Iwluca{
    address private _owner;
    address private _minter;

    event ChangeMinter(address oldMinter, address NewMinter);

    modifier onlyOwner() {
        require(msg.sender == _owner, "WLUCA: caller not owner");
        _;
    }

    modifier onlyMinter() {
         require(msg.sender == _minter, "WLUCA: caller not owner");
        _;
    }
    
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){
       _setOwner(msg.sender);
    }
    
    function owner() external view returns(address){
        return _owner;
    }

    function minter() external view returns(address) {
        return _minter;
    }

    function _setOwner(address user) internal {
        _owner = user;
    }

    function _setMinter(address user) internal {
        address oldMinter = _minter;
        _minter = user;
        emit ChangeMinter(oldMinter, _minter);
    }

    function setMinter(address user) external onlyOwner returns(bool){
        require(user != address(0), "WLUCA: zero address");
        _setMinter(user);
        return true;
    }

    function mint(address user, uint256 value) override external onlyMinter {
        _mint(user, value);
    }
    
    function burn(uint256 value) override external {
        _burn(msg.sender, value);
    }
}