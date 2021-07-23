// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../common/interface/IERC20.sol";

interface Ifactory {
    event UpdatetokenConfig(string indexed _symbol, address indexed _tokenAddr, uint256 _minAmount);
    event LinkCreated(address indexed _creater, string indexed _symbol, address _link);
    
    function setRisk() external;
    function setOwner(address _user) external;
    function setPledger(address _user) external;
    function setCollector(address _user) external;
    function getCollector() external view returns(address);
    function isLink(address _link) external view returns(bool);
    function isAllowedToken(string memory _symbol, address _addr) external returns(bool);
    function createLink(address _toUser, string memory _tokenSymbol, uint256 _amount, uint256 _percentA, uint256 _lockDays) payable external returns(address);
    function addToken(address _tokenAddr, uint256 _minAmount) external;
    function updateTokenConfig (string memory _symbol, address _tokenAddr, uint256 _minAmount) external;
}

interface ERC20_Token is IERC20 {
    function symbol() external view returns(string memory);
}

interface IWETH is IERC20{
    function deposit() payable external;
    function withdraw(uint) external;
}
