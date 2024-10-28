// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahliaFlashLoanCallback} from "src/core/interfaces/IDahliaCallbacks.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract FlashLoanIntegration is Test, IDahliaFlashLoanCallback {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function onDahliaSupplyCollateral(uint256 amount, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector;
        (selector, data) = abi.decode(data, (bytes4, bytes));
        if (selector == this.test_int_flashActions.selector) {
            uint256 toBorrow = abi.decode(data, (uint256));
            $.collateralToken.setBalance(address(this), amount);
            $.collateralToken.approve(address($.dahlia), amount);
            $.dahlia.borrow($.marketId, toBorrow, 0, address(this), address(this));
        }
    }

    function onDahliaRepay(uint256 amount, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector;
        (selector, data) = abi.decode(data, (bytes4, bytes));
        if (selector == this.test_int_flashActions.selector) {
            uint256 toWithdraw = abi.decode(data, (uint256));

            $.loanToken.approve(address($.dahlia), amount);
            $.dahlia.withdrawCollateral($.marketId, toWithdraw, address(this), address(this));
        }
    }

    function onDahliaFlashLoan(uint256 amount, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector = abi.decode(data, (bytes4));
        if (selector == this.test_int_flashLoan_success.selector) {
            assertEq($.loanToken.balanceOf(address(this)), amount);
            $.loanToken.approve(address($.dahlia), amount);
        }
    }

    function test_int_flashLoan_ZeroAssets() public {
        vm.expectRevert(Errors.ZeroAssets.selector);
        $.dahlia.flashLoan(address($.loanToken), 0, abi.encode(this.test_int_flashLoan_ZeroAssets.selector));
    }

    function test_int_flashLoan_shouldRevertIfNotReimbursed(uint256 amount) public {
        vm.pauseGasMetering();
        amount = vm.boundAmount(amount);
        vm.dahliaLendBy($.carol, amount, $);

        $.loanToken.approve(address($.dahlia), 0);

        vm.resumeGasMetering();
        vm.expectRevert("ERC20: subtraction underflow");
        $.dahlia.flashLoan(
            address($.loanToken),
            amount,
            abi.encode(this.test_int_flashLoan_shouldRevertIfNotReimbursed.selector, TestConstants.EMPTY_CALLBACK)
        );
    }

    function test_int_flashLoan_success(uint256 amount) public {
        vm.pauseGasMetering();
        amount = vm.boundAmount(amount);

        vm.dahliaLendBy($.carol, amount, $);
        vm.resumeGasMetering();
        $.dahlia.flashLoan(address($.loanToken), amount, abi.encode(this.test_int_flashLoan_success.selector));
        vm.pauseGasMetering();

        assertEq($.loanToken.balanceOf(address($.carol)), 0, "Balance of Carol should stay 0");
        assertEq($.loanToken.balanceOf(address($.dahlia)), amount, "Balance of Dahlia the same after");
    }

    function test_int_flashActions(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        $.oracle.setPrice(pos.price);

        vm.dahliaLendBy($.carol, pos.lent, $);

        vm.resumeGasMetering();
        $.dahlia.supplyCollateral(
            $.marketId,
            pos.collateral,
            address(this),
            abi.encode(this.test_int_flashActions.selector, abi.encode(pos.borrowed))
        );
        (, uint256 borrowShares,) = $.dahlia.marketUserPositions($.marketId, address(this));

        assertGt(borrowShares, 0, "no borrow");

        $.dahlia.repay(
            $.marketId,
            pos.borrowed,
            0,
            address(this),
            abi.encode(this.test_int_flashActions.selector, abi.encode(pos.collateral))
        );
        (,, uint256 collateral) = $.dahlia.marketUserPositions($.marketId, address(this));
        assertEq(collateral, 0, "no withdraw collateral");
    }
}
