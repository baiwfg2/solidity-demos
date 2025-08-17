// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            console.log("DeployRaffle::run, ready to create sub and fund it ...");
            CreateSubscription createSub = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSub.createSubscription(config.vrfCoordinatorV2_5, config.account);

            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSub(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        console.log("before deploy, config.account balance:" , address(config.account).balance);
        /*
            在sepolia时，config.account就是在 helperConfig中配的 PubKey, 在anvil时就是foundry的默认帐户
            在 forked Sepolia 本地节点上，你可以用任何账户（包括不是你钱包的地址）部署合约(当然需要有balance),
            因为一切都只在本地模拟，不需要真实私钥和链上余额。
        */
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();

        // We already have a broadcast in here
        addConsumer.doAddConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        console.log("DeployRaffle::run, consumer added, deploy signer: ", raffle.owner());
        return (raffle, helperConfig);
    }
}
