// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

// 把 fund, withdraw 做成脚本(相当于hardhat中的task)，是为了一方面能在测试中使用，另一方面也能直接forge script 运行
contract FundScript is Script {
    uint256 SEND_VALUE = 0.1 ether;

    // 提取单独的函数，方便在测试中调用
    function doFund(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).fund{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded with %s", SEND_VALUE);
    }

    function run() external {
        // 每次自动从 broadcast 中获取最新部署的 FundMe 合约地址
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        doFund(mostRecentlyDeployed);
    }
}

contract WithdrawScript is Script {
    function doWithdraw(address mostRecentlyDeployed) public {
        // 如果没用startBroadcast，则会报 FundMe__NotOwner
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).withdraw();
        vm.stopBroadcast();
        console.log("Withdraw done");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        doWithdraw(mostRecentlyDeployed);
    }
}
