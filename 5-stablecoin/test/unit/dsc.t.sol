import { Test, console } from "forge-std/Test.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";

contract DscTest is Test {
    DecentralizedStableCoin dsc;
    address user = makeAddr("user");

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    function testDscBurnAmountZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testDscBurnAmountLargerThanBalance() public {
        vm.startPrank(dsc.owner());
        dsc.mint(user, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector, 2 ether));
        dsc.burn(2 ether);
        vm.stopPrank();
    }

    function testDscAddressZero() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert(abi.encodeWithSelector(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector));
        dsc.mint(address(0), 1 ether);
        vm.stopPrank();
    }

    function testDscMintAmountZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        dsc.mint(user, 0);
    }
}