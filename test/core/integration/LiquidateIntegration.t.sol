// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract LiquidateIntegration is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_liquidate_marketNotDeployed(Types.MarketId marketIdFuzz) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.liquidate(marketIdFuzz, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_zeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.liquidate($.marketId, address(0), TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_healthyPosition(TestTypes.MarketPosition memory pos, uint256 collateralSeized) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv - 1);
        collateralSeized = bound(collateralSeized, 1, pos.collateral);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        uint256 positionLTV = $.dahlia.getPositionLTV($.marketId, $.alice);
        (uint256 borrowedAssets,,) = $.dahlia.marketUserMaxBorrows($.marketId, $.alice);
        vm.dahliaPrepareLoanBalanceFor($.bob, borrowedAssets, $);

        vm.prank($.bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.HealthyPositionLiquidation.selector, positionLTV, $.marketConfig.lltv)
        );
        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_margin(TestTypes.MarketPosition memory pos, uint256 amountSeized, uint256 elapsed)
        public
    {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        elapsed = bound(elapsed, 0, 365 days);
        amountSeized = bound(amountSeized, 1, pos.collateral);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.warp(block.timestamp + elapsed);

        $.dahlia.accrueMarketInterest($.marketId);

        uint256 positionLTV = $.dahlia.getPositionLTV($.marketId, $.alice);
        vm.assume(positionLTV < $.marketConfig.lltv);

        // Bob is LIQUIDATOR
        vm.dahliaPrepareLoanBalanceFor($.bob, pos.borrowed, $);
        vm.startPrank($.bob);
        if (positionLTV < $.marketConfig.lltv) {
            vm.expectRevert(
                abi.encodeWithSelector(Errors.HealthyPositionLiquidation.selector, positionLTV, $.marketConfig.lltv)
            );
        }
        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_liquidate_mathematic(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, MarketMath.toPercent(130));

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        Types.Market memory market = $.dahlia.getMarket($.marketId);

        (, uint256 borrowShares, uint256 collateral) = $.dahlia.marketUserPositions($.marketId, $.alice);

        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalBorrowShares = market.totalBorrowShares;
        uint256 bonusRate = market.liquidationBonusRate;
        uint256 collateralPrice = pos.price;

        uint256 borrowedAssets = borrowShares.toAssetsDown(totalBorrowAssets, totalBorrowShares);
        uint256 borrowedInCollateral = borrowedAssets.lendToCollateralUp(collateralPrice);
        uint256 expectedBonusInCollateral =
            FixedPointMathLib.min(borrowedInCollateral, collateral).mulPercentUp(bonusRate);

        uint256 expectedSeizeCollateral = borrowedInCollateral + expectedBonusInCollateral;
        (
            uint256 _borrowAssets,
            uint256 _seizedCollateral,
            uint256 _bonusCollateral,
            uint256 _badDebtAssets,
            uint256 _badDebtShares
        ) = MarketMath.calcLiquidation(
            totalBorrowAssets, totalBorrowShares, collateral, collateralPrice, borrowShares, bonusRate
        );

        // vm.assume(_badDebtShares > 0);

        assertEq(_borrowAssets, borrowedAssets, "borrow asset calculated correctly");
        assertTrue(_seizedCollateral <= collateral, "check bonus");
        assertEq(_bonusCollateral, expectedBonusInCollateral, "got max of collateral");

        if (_badDebtShares > 0) {
            assertTrue(_badDebtShares > 0);
            assertTrue(_badDebtAssets > 0);

            assertEq(_seizedCollateral, collateral, "got max of collateral");
            assertTrue(_seizedCollateral < expectedSeizeCollateral, "real seized mus be less");

            uint256 badDebtInCollateral = expectedSeizeCollateral - collateral;
            uint256 badDebtInAssets = badDebtInCollateral.collateralToLendUp(collateralPrice);
            assertEq(badDebtInAssets, _badDebtAssets, "bad debt assets");

            uint256 badDebtInShares = badDebtInAssets.toSharesUp(totalBorrowAssets, totalBorrowShares);
            assertEq(badDebtInShares, _badDebtShares, "bad debt shares");
        } else {
            assertEq(_badDebtAssets, 0);
            assertEq(_badDebtShares, 0);
            // assertEq(_rescueAssets, 0);
            // assertEq(_rescueShares, 0);
            assertEq(_seizedCollateral, expectedSeizeCollateral);
            assertEq(
                _seizedCollateral - expectedBonusInCollateral, borrowedInCollateral, "bonus is included into seized"
            );
            assertTrue(expectedSeizeCollateral <= collateral);
        }
    }

    function test_int_liquidate_noReserveShares(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, TestConstants.MAX_TEST_LLTV);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
        Types.Market memory market = $.dahlia.getMarket($.marketId);

        uint256 totalLentInShares = pos.lent.toSharesDown(market.totalLendAssets, market.totalLendShares);
        (, uint256 borrowShares, uint256 maxCollateral) = $.dahlia.marketUserPositions($.marketId, $.alice);

        (
            uint256 _borrowAssets,
            uint256 _seizedCollateral,
            uint256 _bonusCollateral,
            uint256 _badDebtAssets,
            uint256 _badDebtShares
        ) = MarketMath.calcLiquidation(
            market.totalBorrowAssets,
            market.totalBorrowShares,
            maxCollateral,
            pos.price,
            borrowShares,
            market.liquidationBonusRate
        );

        uint256 repaidAssets = _borrowAssets - _badDebtAssets;
        uint256 repaidShares = borrowShares - _badDebtShares;

        // Bob is LIQUIDATOR
        vm.dahliaPrepareLoanBalanceFor($.bob, repaidAssets, $);

        vm.prank($.bob);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.DahliaLiquidate(
            $.marketId,
            $.bob,
            $.alice,
            repaidAssets,
            repaidShares,
            _seizedCollateral,
            _bonusCollateral,
            _badDebtAssets,
            _badDebtShares,
            0,
            0
        );
        vm.resumeGasMetering();
        (uint256 returnRepaidAssets,, uint256 returnSeizedCollateral) =
            $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);

        vm.pauseGasMetering();
        uint256 expectedLeftCollateral = pos.collateral - _seizedCollateral;
        (uint256 borrowAssets, uint256 newBorrowShares, uint256 newCollateral) =
            $.dahlia.marketUserPositions($.marketId, $.alice);

        Types.Market memory m = $.dahlia.getMarket($.marketId);
        assertEq(returnSeizedCollateral, _seizedCollateral, "returned seized collateral");
        assertEq(returnRepaidAssets, repaidAssets, "returned asset amount");
        assertEq(borrowAssets, 0, "borrow assets");
        assertEq(newBorrowShares, 0, "borrow shares");
        assertEq(newCollateral, expectedLeftCollateral, "collateral");
        assertEq(m.totalLendAssets, pos.lent - _badDebtAssets, "total lend assets decreased with bad data");
        assertEq(m.totalLendShares, totalLentInShares, "total lend stay same with bas data");
        assertTrue(_bonusCollateral > 0, "_bonusCollateral must be positive");
        assertEq(m.totalBorrowAssets, 0, "total borrow shares");
        assertEq(m.totalBorrowShares, 0, "total borrow shares");
        assertEq($.loanToken.balanceOf($.alice), pos.borrowed, "borrower balance");
        assertEq($.loanToken.balanceOf($.bob), 0, "liquidator balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), pos.lent - _badDebtAssets, "Dahlia balance");
        assertEq($.collateralToken.balanceOf(address($.dahlia)), expectedLeftCollateral, "Dahlia collateral balance");
        assertEq($.collateralToken.balanceOf($.bob), returnSeizedCollateral, "liquidator collateral balance");
    }

    function test_int_liquidate_withReservSharese(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        address reserveAddress = ctx.createWallet("RESERVE_FEE_RECIPIENT");
        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, TestConstants.MAX_TEST_LLTV);

        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
        uint256 reserveAssets = vm.randomUint(0, 1e10);
        // lend shares by reserve
        vm.dahliaLendBy(reserveAddress, reserveAssets, $);

        Types.Market memory market = $.dahlia.getMarket($.marketId);
        uint256 prevTotalLentShares = market.totalLendShares;
        (, uint256 borrowShares, uint256 maxCollateral) = $.dahlia.marketUserPositions($.marketId, $.alice);

        (
            uint256 _borrowAssets,
            uint256 _seizedCollateral,
            uint256 _bonusCollateral,
            uint256 _badDebtAssets,
            uint256 _badDebtShares
        ) = MarketMath.calcLiquidation(
            market.totalBorrowAssets,
            market.totalBorrowShares,
            maxCollateral,
            pos.price,
            borrowShares,
            market.liquidationBonusRate
        );

        (uint256 reserveLendShares,,) = $.dahlia.marketUserPositions($.marketId, reserveAddress);
        (uint256 _rescueAssets, uint256 _rescueShares) = MarketMath.calcRescueAssets(
            market.totalLendAssets, market.totalLendShares, _badDebtAssets, reserveLendShares
        );
        uint256 repaidAssets = _borrowAssets - _badDebtAssets;
        uint256 repaidShares = borrowShares - _badDebtShares;

        // Bob is LIQUIDATOR
        vm.dahliaPrepareLoanBalanceFor($.bob, repaidAssets, $);

        vm.prank($.bob);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.DahliaLiquidate(
            $.marketId,
            $.bob,
            $.alice,
            repaidAssets,
            repaidShares,
            _seizedCollateral,
            _bonusCollateral,
            _badDebtAssets,
            _badDebtShares,
            _rescueAssets,
            _rescueShares
        );
        vm.resumeGasMetering();
        (uint256 returnRepaidAssets,, uint256 returnSeizedCollateral) =
            $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);

        vm.pauseGasMetering();
        uint256 expectedLeftCollateral = pos.collateral - _seizedCollateral;
        (uint256 borrowAssets, uint256 newBorrowShares, uint256 newCollateral) =
            $.dahlia.marketUserPositions($.marketId, $.alice);

        uint256 lendBalance = pos.lent + reserveAssets - _badDebtAssets + _rescueAssets;
        uint256 dahliaLoanTokenBalance = pos.lent + reserveAssets - _badDebtAssets;

        Types.Market memory m = $.dahlia.getMarket($.marketId);
        assertEq(returnSeizedCollateral, _seizedCollateral, "returned seized collateral");
        assertEq(returnRepaidAssets, repaidAssets, "returned asset amount");
        assertEq(borrowAssets, 0, "borrow assets");
        assertEq(newBorrowShares, 0, "borrow shares");
        assertEq(newCollateral, expectedLeftCollateral, "collateral");
        assertEq(m.totalLendAssets, lendBalance, "total lend assets decreased with bad data");
        assertEq(m.totalLendShares, prevTotalLentShares - _rescueShares, "total lend stay same with bas data");
        assertTrue(_bonusCollateral > 0, "_bonusCollateral must be positive");
        assertEq(m.totalBorrowAssets, 0, "total borrow shares");
        assertEq(m.totalBorrowShares, 0, "total borrow shares");
        assertEq($.loanToken.balanceOf($.alice), pos.borrowed, "borrower balance");
        assertEq($.loanToken.balanceOf($.bob), 0, "liquidator balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), dahliaLoanTokenBalance, "Dahlia balance");
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

        $.oracle.setPrice(1e36 / 10);

        // Bob is LIQUIDATOR
        $.loanToken.setBalance($.bob, loanAmount);

        vm.startPrank($.bob);
        $.loanToken.approve(address($.dahlia), loanAmount);
        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();
    }

    function test_int_liquidate_seizedAssetsRoundUp() public {
        vm.pauseGasMetering();
        uint256 lltv = MarketMath.toPercent(75);
        TestContext.MarketContext memory $m1 = ctx.bootstrapMarket("USDC", "WBTC", lltv);
        uint256 amountCollateral = 400;
        uint256 amountBorrowed = 300;
        uint256 loanAmount = 100e18;
        vm.dahliaLendBy($m1.carol, loanAmount, $m1);

        vm.dahliaSupplyCollateralBy($m1.alice, amountCollateral, $m1);
        vm.dahliaBorrowBy($m1.alice, amountBorrowed, $m1);

        $m1.oracle.setPrice(1e36 - 0.01e18);

        // Bob is LIQUIDATOR
        $m1.loanToken.setBalance($m1.bob, loanAmount);

        vm.startPrank($m1.bob);
        $m1.loanToken.approve(address($m1.dahlia), loanAmount);
        vm.resumeGasMetering();
        (uint256 returnRepaidAssets,, uint256 returnSeizedCollateral) =
            $m1.dahlia.liquidate($m1.marketId, $m1.alice, TestConstants.EMPTY_CALLBACK);
        vm.pauseGasMetering();
        vm.stopPrank();

        // assertEq(returnSeizedCollateral, 325, "seized collateral");
        assertEq(returnRepaidAssets, 300, "repaid assets");
    }
}
