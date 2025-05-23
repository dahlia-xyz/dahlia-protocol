// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm, console } from "forge-std/Test.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants, TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

contract LiquidateIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for *;
    using MarketMath for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_liquidate_bothZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InconsistentAssetsOrSharesInput.selector));
        $.dahlia.liquidate($.marketId, $.alice, 0, 0, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_marketNotDeployed(IDahlia.MarketId marketIdFuzz) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.expectRevert(abi.encodeWithSelector(Errors.WrongStatus.selector, IDahlia.MarketStatus.Uninitialized));
        $.dahlia.liquidate(marketIdFuzz, $.alice, 0, 10, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_healthyPosition(TestTypes.MarketPosition memory pos, uint256 collateralSeized) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv - 1);
        collateralSeized = bound(collateralSeized, 1, pos.collateral);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        console.log("\nMarket LLTV", market.lltv);
        console.log("liquidationBonusRate", market.liquidationBonusRate);
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        uint256 maxBorrowable = MarketMath.calcMaxBorrowAssets($.dahlia.getPosition($.marketId, $.alice).collateral, collateralPrice, market.lltv);
        (uint256 borrowedAssets,,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice, 0);
        console.log("maxBorrowable", maxBorrowable);
        console.log("borrowedAssets", borrowedAssets);

        vm.dahliaPrepareLoanBalanceFor($.bob, borrowedAssets, $);

        uint256 userBorrowShares = $.dahlia.getPosition($.marketId, $.alice).borrowShares;
        console.log("userBorrowShares", userBorrowShares);

        vm.prank($.bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.HealthyPositionLiquidation.selector, borrowedAssets, maxBorrowable));

        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, userBorrowShares, 0, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_margin(TestTypes.MarketPosition memory pos, uint256 amountSeized, uint256 elapsed) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        elapsed = bound(elapsed, 0, 365 days);
        amountSeized = bound(amountSeized, 1, pos.collateral);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
        assertEq(pos.collateral, $.dahlia.getMarket($.marketId).totalCollateralAssets, "market total collateral assets");

        vm.warp(block.timestamp + elapsed);

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        uint256 maxBorrowable = MarketMath.calcMaxBorrowAssets($.dahlia.getPosition($.marketId, $.alice).collateral, collateralPrice, market.lltv);
        (uint256 borrowedAssets,,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice, 0);
        console.log("maxBorrowable", maxBorrowable);
        console.log("borrowedAssets", borrowedAssets);

        vm.assume(borrowedAssets < maxBorrowable);

        uint256 userBorrowShares = $.dahlia.getPosition($.marketId, $.alice).borrowShares;

        // Bob is LIQUIDATOR
        vm.dahliaPrepareLoanBalanceFor($.bob, pos.borrowed, $);
        vm.startPrank($.bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.HealthyPositionLiquidation.selector, borrowedAssets, maxBorrowable));

        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, userBorrowShares, 0, TestConstants.EMPTY_CALLBACK);
    }

    //    function test_int_liquidate_mathematics(TestTypes.MarketPosition memory pos) public {
    //        vm.pauseGasMetering();
    //        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, BoundUtils.toPercent(130));
    //
    //        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
    //
    //        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
    //
    //        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.alice);
    //
    //        uint256 totalBorrowAssets = market.totalBorrowAssets;
    //        uint256 totalBorrowShares = market.totalBorrowShares;
    //        uint256 bonusRate = market.liquidationBonusRate;
    //        uint256 collateralPrice = pos.price;
    //
    //        uint256 borrowedAssets = userPos.borrowShares.toAssetsDown(totalBorrowAssets, totalBorrowShares);
    //        uint256 borrowedInCollateral = borrowedAssets.lendToCollateralUp(collateralPrice);
    //        uint256 expectedBonusInCollateral = FixedPointMathLib.min(borrowedInCollateral, userPos.collateral).mulPercentUp(bonusRate);
    //
    //        uint256 expectedSeizeCollateral = borrowedInCollateral + expectedBonusInCollateral;
    //        (uint256 _borrowAssets, uint256 _seizedCollateral, uint256 _bonusCollateral, uint256 _badDebtAssets, uint256 _badDebtShares) =
    //            MarketMath.calcLiquidation(totalBorrowAssets, totalBorrowShares, userPos.collateral, collateralPrice, userPos.borrowShares, bonusRate);
    //
    //        // vm.assume(_badDebtShares > 0);
    //
    //        assertEq(_borrowAssets, borrowedAssets, "borrow asset calculated correctly");
    //        assertTrue(_seizedCollateral <= userPos.collateral, "check bonus");
    //        assertEq(_bonusCollateral, expectedBonusInCollateral, "got max of collateral");
    //
    //        if (_badDebtShares > 0) {
    //            assertTrue(_badDebtShares > 0);
    //            assertTrue(_badDebtAssets > 0);
    //
    //            assertEq(_seizedCollateral, userPos.collateral, "got max of collateral");
    //            assertTrue(_seizedCollateral < expectedSeizeCollateral, "real seized mus be less");
    //
    //            uint256 badDebtInCollateral = expectedSeizeCollateral - userPos.collateral;
    //            uint256 badDebtInAssets = badDebtInCollateral.collateralToLendUp(collateralPrice);
    //            assertEq(badDebtInAssets, _badDebtAssets, "bad debt assets");
    //
    //            uint256 badDebtInShares = badDebtInAssets.toSharesUp(totalBorrowAssets, totalBorrowShares);
    //            assertEq(badDebtInShares, _badDebtShares, "bad debt shares");
    //        } else {
    //            assertEq(_badDebtAssets, 0);
    //            assertEq(_badDebtShares, 0);
    //            // assertEq(_rescueAssets, 0);
    //            // assertEq(_rescueShares, 0);
    //            assertEq(_seizedCollateral, expectedSeizeCollateral);
    //            assertEq(_seizedCollateral - expectedBonusInCollateral, borrowedInCollateral, "bonus is included into seized");
    //            assertTrue(expectedSeizeCollateral <= userPos.collateral);
    //        }
    //    }

    function test_int_liquidate_noReserveShares(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        uint256 liquidationBonusRate = $.dahlia.getMarket($.marketId).liquidationBonusRate;
        uint256 minLtv = $.marketConfig.lltv + 1;
        uint256 maxLtv = minLtv + MarketMath.mulPercentUp(Constants.LLTV_100_PERCENT - minLtv, liquidationBonusRate);
        console.log("Market LLTV", $.marketConfig.lltv);
        console.log("liquidationBonusRate", liquidationBonusRate);

        pos = vm.generatePositionInLtvRange(pos, minLtv, maxLtv);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);

        uint256 totalLentInShares = pos.lent.toSharesDown(market.totalLendAssets, market.totalLendShares);
        IDahlia.UserPosition memory userPos1 = $.dahlia.getPosition($.marketId, $.alice);

        (uint256 _borrowAssets, uint256 _seizedCollateral, uint256 _bonusCollateral, uint256 _badDebtAssets, uint256 _badDebtShares) = MarketMath
            .calcLiquidation(market.totalBorrowAssets, market.totalBorrowShares, userPos1.collateral, pos.price, userPos1.borrowShares, market.liquidationBonusRate);

        uint256 repaidAssets = _borrowAssets - _badDebtAssets;
        uint256 repaidShares = userPos1.borrowShares - _badDebtShares;

        // Bob is LIQUIDATOR
        vm.dahliaPrepareLoanBalanceFor($.bob, repaidAssets, $);

        uint256 userBorrowShares = $.dahlia.getPosition($.marketId, $.alice).borrowShares;

        vm.prank($.bob);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.Liquidate(
            $.marketId, $.bob, $.alice, repaidAssets, repaidShares, _seizedCollateral, _bonusCollateral, _badDebtAssets, _badDebtShares, pos.price
        );

        vm.resumeGasMetering();
        (uint256 returnRepaidAssets, uint256 returnSeizedCollateral) =
            $.dahlia.liquidate($.marketId, $.alice, userBorrowShares, 0, TestConstants.EMPTY_CALLBACK);

        vm.pauseGasMetering();
        uint256 expectedLeftCollateral = pos.collateral - _seizedCollateral;
        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.alice);

        IDahlia.Market memory m = $.dahlia.getMarket($.marketId);
        assertEq(returnSeizedCollateral, _seizedCollateral, "returned seized collateral");
        assertEq(returnRepaidAssets, repaidAssets, "returned asset amount");
        assertEq(userPos.lendShares, 0, "lend shares");
        assertEq(userPos.borrowShares, 0, "borrow shares");
        assertEq(userPos.collateral, expectedLeftCollateral, "collateral");
        assertEq(pos.collateral - returnSeizedCollateral, m.totalCollateralAssets, "market total collateral after liquidation");
        assertEq(m.totalLendAssets, pos.lent - _badDebtAssets, "total lend assets decreased with bad data");
        assertEq(m.totalLendShares, totalLentInShares, "total lend stay same with bas data");
        assertTrue(_bonusCollateral > 0, "_bonusCollateral must be positive");
        assertEq(m.totalBorrowAssets, 0, "total borrow shares");
        assertEq(m.totalBorrowShares, 0, "total borrow shares");
        assertEq($.loanToken.balanceOf($.alice), pos.borrowed, "borrower balance");
        assertEq($.loanToken.balanceOf($.bob), 0, "liquidator balance");
        assertEq($.loanToken.balanceOf(address($.vault)), pos.lent - _badDebtAssets, "Dahlia balance");
        assertEq($.collateralToken.balanceOf(address($.dahlia)), expectedLeftCollateral, "Dahlia collateral balance");
        assertEq($.collateralToken.balanceOf($.bob), returnSeizedCollateral, "liquidator collateral balance");
    }

    function test_int_liquidate_badDebtOverTotalBorrowAssets() public {
        vm.pauseGasMetering();
        uint256 amountCollateral = 10 ether;
        uint256 loanAmount = 1 ether;

        vm.dahliaLendBy($.carol, loanAmount, $);
        vm.dahliaSupplyCollateralBy($.alice, amountCollateral, $);
        vm.dahliaBorrowBy($.alice, loanAmount, $);

        uint256 newOraclePrice = 1e36 / 10; // price 10 times lower
        console.log("newOraclePrice=", newOraclePrice);
        $.oracle.setPrice(newOraclePrice);

        // Bob is LIQUIDATOR
        $.loanToken.setBalance($.bob, loanAmount);

        vm.startPrank($.bob);
        $.loanToken.approve(address($.dahlia), loanAmount);

        uint256 collateral = $.dahlia.getPosition($.marketId, $.alice).collateral;

        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, 0, collateral, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();
    }

    function test_int_liquidate_seizedAssetsRoundUp() public {
        vm.pauseGasMetering();
        uint256 lltv = BoundUtils.toPercent(75);
        TestContext.MarketContext memory $m1 = ctx.bootstrapMarket("USDC", "WBTC", lltv);
        uint256 amountCollateral = 400; // 400 collateral
        uint256 amountBorrowed = 300; // exact 75%
        uint256 loanAmount = 100e18; // 100 ETH
        (uint256 price,) = $m1.oracle.getPrice();
        console.log("oracle price", price);
        vm.dahliaLendBy($m1.carol, loanAmount, $m1); // Huge loan just to have enough liquidity

        vm.dahliaSupplyCollateralBy($m1.alice, amountCollateral, $m1);
        vm.dahliaBorrowBy($m1.alice, amountBorrowed, $m1);
        uint256 newPrice = 1e36 - 0.01e18;
        console.log("oracle newpr", newPrice);
        $m1.oracle.setPrice(newPrice);

        // Bob is LIQUIDATOR
        $m1.loanToken.setBalance($m1.bob, loanAmount);

        vm.startPrank($m1.bob);
        $m1.loanToken.approve(address($m1.dahlia), loanAmount);

        uint256 userBorrowShares = $m1.dahlia.getPosition($m1.marketId, $m1.alice).borrowShares;
        console.log("userBorrowShares=", userBorrowShares);

        vm.resumeGasMetering();
        (uint256 returnRepaidAssets,) = $m1.dahlia.liquidate($m1.marketId, $m1.alice, userBorrowShares, 0, TestConstants.EMPTY_CALLBACK);
        vm.pauseGasMetering();
        vm.stopPrank();

        // assertEq(returnSeizedCollateral, 325, "seized collateral");
        assertEq(returnRepaidAssets, 300, "repaid assets");
    }
}
