// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm, console } from "@forge-std/Test.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

contract CantinaFindingsTest is Test {
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

    function onDahliaFlashLoan(uint256 amount, uint256 fee, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector = abi.decode(data, (bytes4));

        if (selector == this.test_finding303_flashLoan_reentrancy.selector) {
            uint256 currentBalance = $.loanToken.balanceOf(address(this));

            console.log("current balance", currentBalance);
            if (currentBalance < amount * 3) {
                $.loanToken.approve(address($.dahlia), currentBalance + fee);

                $.dahlia.flashLoan($.marketId, amount, data);
            }

            if (currentBalance == amount * 3) {
                $.loanToken.approve(address($.dahlia), currentBalance + fee);
            }
        }
    }

    function test_finding303_flashLoan_reentrancy() public {
        uint256 amount = 1000e18;
        address location = address($.vault);

        vm.dahliaLendBy($.carol, amount * 4, $);
        uint256 initialBalance = $.loanToken.balanceOf(location);

        bytes memory callbackData = abi.encode(this.test_finding303_flashLoan_reentrancy.selector);
        $.dahlia.flashLoan($.marketId, amount, callbackData);

        assertEq($.loanToken.balanceOf(address(this)), 0, "Attacker should not profit from reentrancy");
        assertEq($.loanToken.balanceOf(location), initialBalance, "Vault balance should not decrease");
    }

    function test_finding301_principalNotLotDuringTransfer() public {
        // Initial deposit
        uint256 initialDeposit = 1000e6;
        deal(address($.loanToken), address(this), initialDeposit);
        $.loanToken.approve(address($.vault), initialDeposit);
        $.vault.deposit(initialDeposit, address(this));

        // Record initial principal
        uint256 initialPrincipal = $.vault.principal(address(this));

        // Perform multiple transfers
        address[] memory recipients = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            recipients[i] = address(uint160(i + 1));
            uint256 sharesToTransfer = $.vault.balanceOf(address(this)) / 10;

            $.vault.transfer(recipients[i], sharesToTransfer);
        }

        // Calculate total principal after transfers
        uint256 totalPrincipalAfter = $.vault.principal(address(this));
        for (uint256 i = 0; i < 5; i++) {
            totalPrincipalAfter += $.vault.principal(recipients[i]);
        }

        assertTrue(totalPrincipalAfter == initialPrincipal, "Principal was NOT lost during transfers");
    }

    function test_finding300_incorrectRatePrediction() public {
        // Setup initial market conditions
        $ = ctx.bootstrapMarket("USDC", "WBTC", BoundUtils.toPercent(80));
        uint256 depositAmount = 10_000e8;
        uint256 collateralAmount = 1000e8;
        uint256 borrowAmount = 500e8;
        $.oracle.setPrice(1e36);

        deal(address($.loanToken), address(this), depositAmount);
        $.loanToken.approve(address($.vault), depositAmount);
        $.vault.deposit(depositAmount, address(this));

        deal(address($.collateralToken), address(this), collateralAmount);
        $.collateralToken.approve(address($.dahlia), collateralAmount);
        $.dahlia.supplyCollateral($.marketId, collateralAmount, address(this), "");
        $.dahlia.borrow($.marketId, borrowAmount, address(this), address(this));
        // Get initial rate prediction
        uint256 initialRate = $.dahlia.previewLendRateAfterDeposit($.marketId, 0);

        // Advance time significantly
        vm.warp(block.timestamp + 7 days);

        // Get new rate prediction
        uint256 newRate = $.dahlia.previewLendRateAfterDeposit($.marketId, 0);

        // Get actual rate after accrual
        // $.dahlia.accrueMarketInterest($.marketId);
        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);

        // New rate prediction should differ from actual rate
        assertLt(initialRate, newRate, "Rate prediction changed despite time passage");
        assertTrue(newRate < market.ratePerSec, "Predicted rate lower than actual");
    }

    function test_finding296_sandwichAttack() public {
        $ = ctx.bootstrapMarket("USDC", "WBTC", BoundUtils.toPercent(80));
        uint256 attackerFunds = 1_000_000e6;
        uint256 victimDeposit = 10_000e6;

        deal(address($.loanToken), $.bob, attackerFunds);
        deal(address($.loanToken), $.carol, victimDeposit);

        uint256 initialSharePrice = $.vault.convertToShares(1e6);

        vm.startPrank($.bob);
        $.loanToken.approve(address($.vault), attackerFunds);
        $.vault.deposit(attackerFunds, $.bob);
        vm.stopPrank();

        vm.startPrank($.carol);
        $.loanToken.approve(address($.vault), victimDeposit);
        uint256 victimShares = $.vault.deposit(victimDeposit, $.carol);
        vm.stopPrank();

        vm.startPrank($.bob);
        $.vault.withdraw(attackerFunds, $.bob, $.bob);
        vm.stopPrank();

        uint256 expectedShares = victimDeposit * initialSharePrice / 1e6;
        assertEq(victimShares, expectedShares);
    }
}
