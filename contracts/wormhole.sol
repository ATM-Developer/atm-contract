// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Wormhole{
    string public networkName;
    mapping(address => mapping(string => address)) holeRigest;

    event RigestHole(address indexed from, string net, address targer);

    constructor(string memory net) {
        networkName = net;
    }

    function getHole(string memory net) external view returns(address){
        return holeRigest[msg.sender][net];
    }

    function rigestHole(string memory net,  address targer) external returns(bool){
        holeRigest[msg.sender][net] = targer;
        emit RigestHole(msg.sender, net, targer);
        return true;
    }
}