// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { DeployDsc } from "../../script/DeployDsc.s.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { HelperConfig, CodeConstants } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockTokenTransferFromFailed, MockTokenTransferFailed, MockTokenMintFailed } from "../mocks/MockUtils.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract DscdsceTest is Test, CodeConstants {
    DeployDsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig.NetworkConfig cfg;

    // these two are frequently used, so set separate fields for them
    address public weth;
    address public wbtc;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address user = makeAddr("user");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    function setUp() public {
        HelperConfig _cfg;

        deployer = new DeployDsc();
        (dsc, dsce, _cfg) = deployer.run();
        cfg = _cfg.getConfigByChainId(block.chainid);
        weth = cfg.weth;
        wbtc = cfg.wbtc;

        if (block.chainid == ANVIL_CHAINID) {
            // 给的是 原生 ETH，有需要时再enable
            //vm.deal(user, STARTING_USER_BALANCE);
        }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(cfg.wethPriceFeed);
        feedAddresses.push(cfg.wbtcPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    //////////// price tests
    function testGetTokenAmountFromUsd() public {
        uint256 expectedWeth = 1 ether;
        uint256 amountWeth = dsce.getTokenAmountFromUsd(weth, 4000 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 1e18;
        uint256 actualValue = dsce.getUsdValue(weth, ethAmount);
        uint256 expectValue = 4_000e18;
        assertEq(actualValue, expectValue);
    }

    ///////////// deposit collateral test
    function testRevertsIfTransferFromFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockTokenTransferFromFailed mockCollateralToken = new MockTokenTransferFromFailed();
        tokenAddresses = [address(mockCollateralToken)];
        feedAddresses = [cfg.wethPriceFeed];
        // DSCEngine receives the third parameter as dscAddress, not the tokenAddress used as collateral.
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
        // Doesn't matter, since transfer return false immediately
        // mockCollateralToken.mint(user, amountCollateral);
        vm.startPrank(user);
        // Doesn't matter, since transfer return false immediately
        // ERC20Mock(address(mockCollateralToken)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockCollateralToken), amountCollateral);
        vm.stopPrank();
    }

    function testRevertIfCollateralZero() public {
        vm.startPrank(user);
        // here can omit approve, because 0 is transferred
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock();
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(randToken)));
        dsce.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(user);
        // no mint, so balance is 0
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);
        uint256 realWethDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(realWethDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(cfg.wethPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) /
            dsce.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(
            DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    // testRevertsIfMintedDscBreaksHealthFactor 写得有点复杂，完全可以简化
    function testRevertsIfMintedDscBreaksHealthFactor2() public {
        // 虽然forge test -vvvv 输出中显示 999999999999999999 为 9.999e17 ，这只是近似表达
        //  在实际代码中，就得写准确
        // uint256 expectedHealthFactor = 9.999e17;
        uint256 expectedHealthFactor = 999999999999999999;
        // (4000 * ethAmount * 0.5 * 1e18) / dscToMint = expectedHealthFactor
        uint256 tmpAmountCollateral = 1e18;
        uint256 tmpAmountToMint = 2000e18 + 1;
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), tmpAmountCollateral);
        vm.expectRevert(abi.encodeWithSelector(
            DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDsc(weth, tmpAmountCollateral, tmpAmountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // mintDsc Tests //
    ///////////////////////////////////
    function testRevertsIfMintAmountIsZero() public {
        // no need to do deposit first
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockTokenMintFailed mockDsc = new MockTokenMintFailed();
        tokenAddresses = [weth];
        feedAddresses = [cfg.wethPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
        // mock mint failed, needn't set this
        //mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    // 测试点与 testRevertsIfMintedDscBreaksHealthFactor2 重了
    // function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
    //     (, int256 price,,,) = MockV3Aggregator(cfg.wethPriceFeed).latestRoundData();
    //     amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

    //     vm.startPrank(user);
    //     uint256 expectedHealthFactor =
    //         dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
    //     vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
    //     dsce.mintDsc(amountToMint);
    //     vm.stopPrank();
    // }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        dsce.mintDsc(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnDsc Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    // I think no need to test arithmetic underflow or overflow
    // function testCantBurnMoreThanUserHas() public {
    //     vm.prank(user);
    //     vm.expectRevert();
    //     dsce.burnDsc(1);
    // }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        // ERC20Mock(weth).approve(address(dsce), amountCollateral);
        // dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    // cannot use `depositedCollateral`, since it deposits into normal WETH
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        //address owner = msg.sender;
        vm.prank(user);
        MockTokenTransferFailed mockToken = new MockTokenTransferFailed();
        tokenAddresses = [address(mockToken)];
        feedAddresses = [cfg.wethPriceFeed];
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
        // 重要！user 帐户上得有 MockToken的余额
        mockToken.mint(user, amountCollateral);

        //vm.prank(owner);
        //mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        MockTokenTransferFailed(address(mockToken)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        // 先给用户存入抵押物，否则减法会溢出，走不到后面
        // deposit里用的transferFrom ，不受 mockToken的影响
        mockDsce.depositCollateral(address(mockToken), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.redeemCollateral(address(mockToken), amountCollateral);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        uint256 userBalanceBeforeRedeem = dsce.getCollateralBalanceOfUser(user, weth);
        assertEq(userBalanceBeforeRedeem, amountCollateral);
        dsce.redeemCollateral(weth, amountCollateral);
        uint256 userBalanceAfterRedeem = dsce.getCollateralBalanceOfUser(user, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    // function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
    //     vm.expectEmit(true, true, true, true, address(dsce));
    //     emit CollateralRedeemed(user, user, weth, amountCollateral);
    //     vm.startPrank(user);
    //     dsce.redeemCollateral(weth, amountCollateral);
    //     vm.stopPrank();
    // }

}