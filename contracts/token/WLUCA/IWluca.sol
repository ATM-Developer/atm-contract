// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ERC20.sol";
interface Iwluca {
    function mint(address user, uint amount) external;
    function burn(uint amount) external;
}
