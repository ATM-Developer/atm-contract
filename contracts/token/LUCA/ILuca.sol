// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../../common/interface/IERC20.sol";

interface ILuca is IERC20{
    //event
    event Rebase(uint256 epoch, uint256 indexDelta, bool positive);
    
    //luca core
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function rebase(uint256 epoch, uint256 indexDelta, bool positive) external returns (uint256);
    function rebaseByMilli(uint256 epoch, uint256 milli, bool positive) external returns (uint256);
    
    //query
    function lucaToFragment(uint256 value) external view returns (uint256);
    function fragmentToLuca(uint256 value) external view returns (uint256);
    
    //manager
    function setMinter(address user) external;
    function setReceiver(address user) external;
    function setRebaser(address user) external;
}
