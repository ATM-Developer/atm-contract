// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IPair {
    function sync() external;
}

interface ILuca {
    function rebaseByMilli(uint256 epoch, uint256 milli, bool positive) external returns (uint256);
    function rebase(uint256 epoch, uint256 indexDelta, bool positive) external returns (uint256);
}
contract Rebaser is OwnableUpgradeable{
    ILuca public luca;
    address[] pairs;

    function __Rebaser_init(address _luca, address[] memory _pairs) external initializer() {
        __Ownable_init();
        __Rebaser_init_unchained(_luca, _pairs);
    }

    function __Rebaser_init_unchained(address _luca, address[] memory _pairs) internal onlyInitializing {
        luca = ILuca(_luca);
        pairs = _pairs;
    }

    function addPair(address _pair) external onlyOwner() {
        pairs.push(_pair);
    }

    function rebaseByMilli(uint256 epoch, uint256 milli, bool positive) external onlyOwner() {
        require(luca.rebaseByMilli(epoch, milli, positive) > 0, "rebaseByMilli error");
        _sync();
    }

    function rebase(uint256 epoch, uint256 indexDelta, bool positive) external onlyOwner() {
        require(luca.rebase(epoch, indexDelta, positive) > 0, "rebase error");
        _sync();
    }

    function _sync() internal {
        for(uint i=0; i<pairs.length; i++ ){
            IPair(pairs[i]).sync();
        }
    }

    function getPairs() external view  returns (address[] memory)  {
        address[] memory _pairs = new address[](pairs.length);
        for(uint i=0; i<pairs.length; i++ ){
            _pairs[i] = pairs[i];
        }
        return _pairs;
    }

}




