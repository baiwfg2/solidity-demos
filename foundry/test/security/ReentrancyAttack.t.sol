import { Test } from "forge-std/Test.sol";
import { TheBank, TheAttacker } from "../../src/security/ReentrancyAttack.sol";
import { console } from "forge-std/console.sol";
//import { console2 } from "forge-std/console2.sol";

contract TheBankTest is Test {
    TheBank bank;
    TheAttacker attacker;
    address user = makeAddr("user");
    address attackerAddr = makeAddr("attacker");

    function setUp() public {
        bank = new TheBank();
        attacker = new TheAttacker(address(bank));
        vm.deal(user, 7 ether);
        vm.deal(attackerAddr, 2 ether);
    }

    function test_deposit() public {
        vm.prank(user);
        bank.deposit{value: 1 ether}();
        assertEq(bank.totalBalance(), 1 ether);
    }

    function test_withdraw() public {
        vm.startPrank(user);
        bank.deposit{value: 1 ether}();
        bank.withdraw();
        vm.stopPrank();
        assertEq(bank.totalBalance(), 0);
    }

    function test_attack() public {
        vm.prank(user);
        bank.deposit{value: 7 ether}();

        vm.prank(attackerAddr);
        bank.deposit{value: 1 ether}();
        assertEq(bank.totalBalance(), 8 ether);

        vm.prank(attackerAddr);
        // Note that the signer that do deposit in attack is not `attackerAddr`, but the `TheAttacker` contract itself !!
        attacker.attack{value: 1 ether}();
        console.log("Attacker balance after attack:", attacker.getBalances());
        assertEq(attacker.getBalances(), 9 ether);
        assertEq(bank.totalBalance(), 0);
    }

    function test_preventAttack() public {
        vm.prank(user);
        bank.deposit{value: 7 ether}();

        vm.startPrank(attackerAddr);
        bank.deposit{value: 1 ether}();
        vm.expectRevert("withdraw failed");
        attacker.attackFailed{value: 1 ether}();
        assertEq(attacker.getBalances(), 0 ether);
        vm.stopPrank();
    }
}