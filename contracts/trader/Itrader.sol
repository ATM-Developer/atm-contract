// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface Itrader {
    function balance() external returns(uint256 luca, uint256 wluca);
    function deposit(uint256 _amount) external returns(bool);
    function withdraw(uint256 _amount) external returns(bool);
    function payment(address _token, address _from, address _to, uint256 _amount) external returns(bool); 
    function withdrawFor(address _to, uint256 _amount) external;
    function addWhiteList(address _addr) external;
    function setFactory(address _factory) external;
}
