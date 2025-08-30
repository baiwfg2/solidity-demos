// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { DeployDsc } from "../script/DeployDsc.s.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { HelperConfig, CodeConstants } from "../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DscEngineTest is Test, CodeConstants {
    DeployDsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig.NetworkConfig networkCfg;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address user = makeAddr("user");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    function setUp() public {
        HelperConfig cfg;

        deployer = new DeployDsc();
        (dsc, engine, cfg) = deployer.run();
        networkCfg = cfg.getConfigByChainId(block.chainid);

        if (block.chainid == ANVIL_CHAINID) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 2e18;
        uint256 actualValue = engine.getUsdValue(networkCfg.weth, ethAmount);
        uint256 expectValue = 3_000e18;
        assertEq(actualValue, expectValue);
    }

    function testRevertIfCollateralZero() public {
        vm.startPrank(user);
        // here can omit approve, because 0 is transferred
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(networkCfg.weth, 0);
        vm.stopPrank();
    }
}