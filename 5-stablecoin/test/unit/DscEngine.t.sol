// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test, console } from "forge-std/Test.sol";
import { DeployDsc } from "../../script/DeployDsc.s.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { HelperConfig, CodeConstants } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockTokenTransferFromFailed, MockTokenTransferFailed, MockTokenMintFailed } from "../mocks/MockUtils.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract DscEngineTest is Test, CodeConstants {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

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

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

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

    function testBurnDscTransferFailed() public {
        // Arrange - Setup
        MockTokenTransferFromFailed mockDsc = new MockTokenTransferFromFailed();
        tokenAddresses = [weth];
        feedAddresses = [cfg.wethPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);
        mockDsce.depositCollateralAndMintDsc(tokenAddresses[0], amountCollateral, amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.burnDsc(amountToMint);
        vm.stopPrank();
    }

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

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        /*
        第1个 true：检查 topic1 (redeemFrom)
        验证 redeemFrom 是否等于期望的 user

        第2个 true：检查 topic2 (redeemTo)
        验证 redeemTo 是否等于期望的 user

        第3个 true：检查 topic3
        但这个事件没有第3个 indexed 参数，所以这个参数实际无效

        第4个 true：检查 data 部分
        验证非 indexed 的数据：token 和 amount
        address(dsce)：指定事件发出者

        验证事件必须从 dsce 合约发出
        */
        vm.expectEmit(true, true, false, true, address(dsce));
        emit CollateralRedeemed(user, user, weth, amountCollateral);
        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        //dsc.approve(address(dsce), amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.redeemCollateralForDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // seems that no `MockMoreDebtDSC` is needed
    function testMustImproveHealthFactorOnLiquidation() public depositedCollateralAndMintedDsc {
        // Arrange - 给liquidator 一定的抵押品
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        uint256 debtToCover = 10 ether; // 需要清算的债务，不一定是用户的总债务
        // 在eth 价格未变时，清算者的health factor还是正常的
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), debtToCover);
        // 设置eth价格大跌，以使得user 的health factor不满足条件
        int256 ethUsdUpdatedPrice = 10e8;
        MockV3Aggregator(cfg.wethPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        /*
          user的startingHealthFactor = 10 * P * 0.5 / 100 >= 1时， P>=20

          当 P = 10时， user的 startingUserHealthFactor = 0.5

          user 状态：
            collateral = amountCollateral - (debtToCover / P) * 1.1
                = 10 - (10/P) * 1.1
            dsc 剩下： 100 - 10 = 90
            当 P = 10时，endingUserHealthFactor = ((10 - 1.1) * 10* 0.5 / 90) e18 < 0.5e18
            因此，此时 user 的health factor 没有改善

          liquidator 状态：
            由getTokenAmountFromUsd知可得到的collateral = debtToCover / 2 = 5 eth
            算上bonus，total_collateral = collateralToCover + 5 + 0.1 * 5 = 6.5 eth
            为user偿还DSC后，剩下total_dsc = amountToMint - debtToCover = 100 - 10 = 90
        */
        dsce.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        // dsc.approve(address(dsce), amountToMint); // not necessary

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, user, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint); // 10, 100
        vm.stopPrank();

        int256 ethUsdUpdatedPrice = 18e8;
        MockV3Aggregator(cfg.wethPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint); // 20, 100
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, user, amountToMint); // We are covering their whole debt
        /*
          user的startingHealthFactor = 10 * P * 0.5 / 100 >= 1时， P>=20

          为了能继续清算，P < 20

          user 状态：
            collateral = amountCollateral - (debtToCover / P) * 1.1
                = 10 - (10/P) * 1.1
            
          liquidator 状态：
            由getTokenAmountFromUsd知可得到的collateral = debtToCover / P = 100/18 = 5.555555555555555
            算上bonus，total_collateral = collateralToCover + 100/P * 1.1 = 20 + 5.5 = 25.5 (其中只有 100/P*1.1 在ERC20Mock balance中)
            为user偿还DSC后，剩下total_dsc = amountToMint - debtToCover = 100 - 100 = 0
        */
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());
        // 花了很久理解，为何结果是 6_111_111_111_111_111_110 = 5555555555555555555 + 555555555555555555
        // 而不是 100/18 * 1.1 = 6.111111111111112
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());

        uint256 usdAmountLiquidated = dsce.getUsdValue(weth, amountLiquidated);
        uint256 totalCollateralUsd = dsce.getUsdValue(weth, amountCollateral);
        console.log("totalCollateralUsd:", totalCollateralUsd, ", liquidatedUsd:", usdAmountLiquidated);
        console.log("amountLiquidated:", amountLiquidated); // 6111111111111111110
        // user 剩余的抵押品价值
        uint256 expectedUserCollateralValueInUsd = totalCollateralUsd - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = dsce.getAccountInformation(user);
        // 10e18 * 18 - 6_111_111_111_111_111_110 * 18
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorStateAfterLiquidation() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInformation(liquidator);
        // 清算只是burn user的dsc，不是burn liquidator自己的，因此 s_DSCMinted[liquidator] 并未变
        // DSC 债务：100（不变，这是他自己铸造的债务）; DSC 余额：0（用于清算了）
        assertEq(liquidatorDscMinted, amountToMint);
        uint256 userBalance = dsc.balanceOf(liquidator);
        assertEq(userBalance, 0);
    }

    function testUserStateAfterLiquidation() public liquidated {
        (uint256 userDscMinted,) = dsce.getAccountInformation(user);
        assertEq(userDscMinted, 0);

        uint256 userBalance = dsc.balanceOf(user);
        // user 的DSC 仍在 DSC token里，不会被liquidate 处理
        assertEq(userBalance, amountToMint);
    }

    // some view or pure function tests
    function testGetLiquidationThreshold() public {
        uint256 threshold = dsce.getLiquidationThreshold();
        assertEq(threshold, 50); // 50%
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, 1e18);
    }

    function testGetCollateralTokens() public {
        address[] memory tokens = dsce.getCollateralTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], weth);
        assertEq(tokens[1], wbtc);
    }
}