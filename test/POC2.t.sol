// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { POSTest } from "./POSTest.sol";
import { console } from "@forge-std/console.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Vm } from "forge-std/Test.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

// Test for tracking and validating market interest accruals, lender/borrower positions,
// and fee distribution in Dahlia Protocol.
contract POS2Test is POSTest {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;
    using LibString for uint256;

    // Sets up the test environment by creating a lending market with 80% Liquidation Loan-to-Value.
    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", BoundUtils.toPercent(80));
    }

    // Validates interest accrual and interaction with lending rates over a series of blocks.
    function test_int_accrueInterest_Test2() public {
        vm.pauseGasMetering();

        // Define initial market position parameters
        TestTypes.MarketPosition memory pos =
            TestTypes.MarketPosition({ collateral: 10_000e8, lent: 10_000e8, borrowed: 1000e8, price: 1e36, ltv: BoundUtils.toPercent(80) });

        uint32 protocolFee = BoundUtils.toPercent(1);

        // Validate initial market conditions
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 0, "start lend rate");
        $.oracle.setPrice(pos.price);

        IDahlia.Market memory market1 = $.dahlia.getMarket($.marketId);
        vm.forward(100_000);
        IDahlia.Market memory market2 = $.dahlia.getMarket($.marketId);
        assertEq(market2.updatedAt - market1.updatedAt, 100_000, "updatedAt changed by 100000 blocks");

        // Simulate market activities: lending, collateral supply, borrowing
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaLendBy($.bob, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);
        vm.dahliaBorrowBy($.alice, pos.borrowed, $);

        (, uint256 aliceShares) = $.dahlia.getPositionInterest($.marketId, $.alice);
        assertEq(aliceShares, 0, "no interest");

        // Ensure fees and rates are set correctly
        uint256 ltv = $.dahlia.getPositionLTV($.marketId, $.alice);
        console.log("ltv: ", ltv);

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        WrappedVault vault = WrappedVault(address(market.vault));
        vm.prank(vault.owner());
        vault.addRewardsToken(address($.loanToken));

        vm.startPrank($.owner);
        if (protocolFee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, protocolFee);
        }
        vm.stopPrank();
        printMarketState("0", "carol and bob has equal position with 10% ltv");
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 8_750_130, "initial lend rate");
        validateUserPos("0", 0, 0, 0, 0);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, pos.lent), 5_647_210, "initial lend rate if deposit more assets");
        validateUserPos("0", 0, 0, 0, 0);

        vm.forward(1);
        (, uint256 aliceShares2) = $.dahlia.getPositionInterest($.marketId, $.alice);
        assertEq(aliceShares2, 0, "no interest");
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 8_750_130, "rate after 1 block");

        uint256 blocks = 10_000;
        vm.forward(blocks - 1);
        validateUserPos("1 ", 86_625_992_497, 86_625_992_497, 86_626, 86_626);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 8_750_145, "lend rate after 10000 blocks");
        assertEq($.vault.previewRateAfterDeposit(address($.loanToken), 0), 8_662_643, "lend rate after 10000 blocks using vault");
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, pos.lent), 5_647_219, "lend rate if deposit more assets more assets");
        assertEq($.vault.previewRateAfterDeposit(address($.loanToken), pos.lent), 5_590_747, "lend rate if deposit more assets using vault");
        vm.dahliaClaimInterestBy($.carol, $);
        validateUserPos("1 claim by carol", 86_625_992_497, 86_625_992_497, 86_626, 86_626);
        assertEq($.dahlia.getMarket($.marketId).ratePerSec, 175_002_615, "rate per second");
        assertLt($.dahlia.previewLendRateAfterDeposit($.marketId, pos.lent), $.dahlia.getMarket($.marketId).ratePerSec);
        printMarketState("1", "interest claimed by carol after 10_000 blocks");

        vm.forward(blocks / 2); // 50 block pass
        printMarketState("2", "accrual of interest and lending again by carol");
        vm.dahliaLendBy($.carol, pos.lent, $);
        validateUserPos("3 lending by carol", 129_938_983_117, 129_938_983_116, 129_939, 129_939);
        printMarketState("3", "carol lending again");
        //        vm.dahliaLendBy($.bob, pos.lent, $);
        //        printMarketState("4.1", "bob lending again");
        uint256 assets = vm.dahliaWithdrawBy($.bob, $.dahlia.getPosition($.marketId, $.bob).lendShares, $);
        validateUserPos("4 after bob withdraw all shares", 0, 129_938_983_117, 0, 129_939);
        printMarketState("4", "after bob withdraw all shares");
        console.log("4 bob assets withdrawn: ", assets);
        vm.dahliaWithdrawBy($.carol, $.dahlia.getPosition($.marketId, $.carol).lendShares / 2, $);
        validateUserPos("5 carol withdraw 1/2 of shares", 0, 129_938_983_117, 0, 129_939);
        printMarketState("5", "carol withdraw 1/2 of shares");
        vm.dahliaClaimInterestBy($.carol, $);
        validateUserPos("5 carol claim interest", 0, 129_938_983_117, 0, 129_939);
        printMarketState("5.1", "interest claimed by carol and 1/2 of shares withdrawn");
        IDahlia.UserPosition memory alicePos = $.dahlia.getPosition($.marketId, $.alice);
        vm.dahliaRepayByShares($.alice, alicePos.borrowShares, $.dahlia.getMarket($.marketId).totalBorrowAssets, $);
        validateUserPos("6 repay by alice", 0, 129_938_983_117, 0, 129_939);
        printMarketState("6", "repay by alice");
        vm.forward(blocks);
        uint256 assets2 = vm.dahliaWithdrawBy($.carol, $.dahlia.getPosition($.marketId, $.carol).lendShares, $);
        validateUserPos("8 carol withdraw all shares", 0, 0, 0, 0);
        printMarketState("8", "after carol withdraw all shares");
        console.log("8 carol assets withdrawn: ", assets2);
        vm.startPrank($.carol);
        // if not position claim will fail with NotPermitted
        // vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, address(market.vault)));
        market.vault.claim($.carol, address($.loanToken));
        assertEq(vault.balanceOf($.protocolFeeRecipient), 2_624_999_658, "protocolFeeRecipient balance");
        vm.startPrank($.protocolFeeRecipient);
        uint256 protocolFees = $.vault.redeem(vault.balanceOf($.protocolFeeRecipient), $.protocolFeeRecipient, $.protocolFeeRecipient);
        assertEq(protocolFees, 2624, "protocol fees");
        printMarketState("9", "after withdrawProtocolFee");
        assertEq(vault.balanceOf($.protocolFeeRecipient), 0, "protocolFeeRecipient balance is 0");
        vm.stopPrank();
        printMarketState("10", "after withdrawReserveFee");
        assertEq(vault.balanceOf($.protocolFeeRecipient), 0, "protocolFeeRecipient balance is 0");
    }
}
