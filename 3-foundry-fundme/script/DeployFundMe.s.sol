// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundMe} from "../src/FundMe.sol";

contract DeployFundMe is Script {
    function deployFundMe() public returns (FundMe, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address priceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;
        // 不属于tx 里的语句都要放在starBroadcast 之前做

        /*
        DeployFundMe 使用了 vm.startBroadcast()
        这将 owner 设置为一个 EOA 地址（不是 DeployFundMe 合约地址），通常是 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        EOA 可以直接接收 ETH，不需要 receive() 函数
        */
        vm.startBroadcast();
        FundMe fundMe = new FundMe(priceFeed);
        vm.stopBroadcast();
        return (fundMe, helperConfig);
    }

    function run() external returns (FundMe, HelperConfig) {
        return deployFundMe();
    }
}
