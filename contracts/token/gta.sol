// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./erc20.sol";
contract GTA is ERC20{
    address public owner;
    address public minter;

    constructor() ERC20("ATM Governance token", "GTA", 18){
        owner = msg.sender;
    }
    
    function setOwner(address user) external{
        require(msg.sender == owner, "GTA: only owner");
        owner = user;
    }
   
    function setMinter(address user) external{
        require(msg.sender == owner, "GTA: only owner");
        minter = user;
    }

    function mint(address to, uint256 value) external{
        require(msg.sender == minter, "GTA: only minter");
        _mint(to, value);
    }
    
    function burn(uint256 amount) external{
        _burn(amount);
    }
}
