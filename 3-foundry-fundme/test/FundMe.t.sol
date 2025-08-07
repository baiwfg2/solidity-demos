// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {DeployFundMe} from "../script/DeployFundMe.s.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig, CodeConstants} from "../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
//import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {MockV3Aggregator} from "../test/MockV3Aggregator.sol";

contract FundMeTest is CodeConstants, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    // 视频11:57:48 谈到 address USER = makeAddr("User");
    uint160 public constant USER_NUMBER = 50;
    address public constant USER = address(USER_NUMBER);

    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    function setUp() external {
        if (true) { // !isZkSyncChain ? 
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
            console.log("DeployFundMe:", address(deployer), ", its balance:", address(deployer).balance);
        } else {
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
            fundMe = new FundMe(address(mockPriceFeed));
        }
        vm.deal(USER, STARTING_USER_BALANCE); // airdrop some ETH to the user
        console.log("owner:", fundMe.getOwner(), ", its balance:", fundMe.getOwner().balance);
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        address expectedPriceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // 预期下一行代码 revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    // https://twitter.com/PaulRBerg/status/1624763320539525121

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(address(3)); // Not the owner
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        console.log("startingFundMeBalance:", startingFundMeBalance);
        console.log("startingOwnerBalance:", startingOwnerBalance);

        // vm.txGasPrice(GAS_PRICE); // 默认anvil上的gas price = 0
        // uint256 gasStart = gasleft();
        // // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
    }

    // Can we do our withdraw function a cheaper way?
    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 100;
        uint160 startingFunderIndex = 2 + USER_NUMBER;

        uint256 originalFundMeBalance = address(fundMe).balance; // This is for people running forked tests!

        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundedeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        uint256 gasStart = gasleft();
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        uint256 gasEnd = gasleft();
        console.log("`withdraw` gas consumed:", gasStart - gasEnd);

        assert(address(fundMe).balance == 0);
        assert(startingFundedeBalance + startingOwnerBalance == fundMe.getOwner().balance);

        uint256 expectedTotalValueWithdrawn = ((numberOfFunders) * SEND_VALUE) + originalFundMeBalance;
        uint256 totalValueWithdrawn = fundMe.getOwner().balance - startingOwnerBalance;

        assert(expectedTotalValueWithdrawn == totalValueWithdrawn);
    }

    function testWithdrawFromMultipleFundersWithCheaperGas() public funded {
        uint160 numberOfFunders = 100;
        uint160 startingFunderIndex = 2 + USER_NUMBER;

        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 gasStart = gasleft();
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw(); // gas 实测比 withdraw 便宜一些
        vm.stopPrank();
        uint256 gasEnd = gasleft();
        console.log("`cheaperWithdraw` gas consumed:", gasStart - gasEnd);
    }
}
