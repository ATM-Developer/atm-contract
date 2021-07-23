// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Initialized {
    bool internal initialized;
    
    modifier noInit(){
        require(!initialized, "initialized");
        _;
        initialized = true;
    }
}

contract Storage is Initialized{
    //ERC20 pubilc variables
    string  public name;
    string  public symbol;
    uint8   public decimals;
    
    //manager 
    address public owner;
    address public rebaser;
    address public minter;
    address public receiver;
    
    //Factor
    uint256 public scalingFactor;
    uint256 internal fragment;
    uint256 internal _totalSupply;
    uint256 constant Decimals = 10**24;
    uint256 constant BASE = 10**18;
    
    mapping (address => uint256) internal fragmentBalances;
    mapping (address => mapping (address => uint256)) internal allowedFragments;
    
    
    //modifier
    modifier onlyRebaser() {
        require(msg.sender == rebaser, "LUCA: only rebaser");
        _;
    }
    
    modifier onlyOwner(){
        require(msg.sender == owner, "LUCA: only owner");
        _;
    }
    
    modifier onlyMinter() {
        require(msg.sender == minter, "LUCA: only minter");
        _;
    }
    
    modifier onlyReceiver() {
        require(msg.sender == receiver, "LUCA: only receiver");
        _;
    }
}

