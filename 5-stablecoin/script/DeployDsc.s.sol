// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { console } from "forge-std/console.sol";

contract DeployDsc is Script {
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        // Storage 变量：编译器允许从固定长度数组隐式转换到动态数组，因为 storage 有足够的灵活性来处理这种转换
        // Memory 变量：在 memory 中，编译器对类型转换更严格，不允许 address[2] memory 到 address[] memory 的隐式转换
        // address[] memory tokenAddresses;
        // address[] memory priceFeedAddresses;

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory cfg = helperConfig.getConfigByChainId(block.chainid);

        tokenAddresses = [cfg.weth, cfg.wbtc];
        priceFeedAddresses = [cfg.wethPriceFeed, cfg.wbtcPriceFeed];

        vm.startBroadcast(cfg.deployer);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        // -vvvvv show : emit OwnershipTransferred(previousOwner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, newOwner: DSCEngine: [xxx]
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (dsc, engine, helperConfig);
    }
}
