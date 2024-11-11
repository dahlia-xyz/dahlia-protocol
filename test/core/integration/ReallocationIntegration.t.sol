// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";

import {TestConstants} from "test/common/TestConstants.sol";
import {TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract ReallocationIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $m1;
    TestContext.MarketContext $m2;
    TestContext ctx;
    address borrower;
    address lender;
    address reallocator;
    IDahlia dahlia;

    function setUp() public {
        ctx = new TestContext(vm);
        $m1 = ctx.bootstrapMarket("USDC", "WBTC", MarketMath.toPercent(70), MarketMath.toPercent(80));
        $m2 = ctx.bootstrapMarket(
            ctx.copyMarketConfig($m1.marketConfig, MarketMath.toPercent(80), MarketMath.toPercent(90))
        );
        borrower = $m1.alice;
        lender = $m1.carol;
        reallocator = $m1.bob;
        dahlia = $m1.dahlia;
    }

    function test_int_reallocate_success(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $m1.marketConfig.rltv + 1, $m1.marketConfig.lltv - 1);

        vm.dahliaSubmitPosition(pos, lender, borrower, $m1);
        vm.dahliaLendBy(lender, pos.lent, $m2);

        uint256 bonusRate = dahlia.getMarket($m1.marketId).reallocationBonusRate;
        // calculate bonus for rellocator with borrowAssets by reallocationBonusRate
        uint256 bonusByBorrowAssets = pos.borrowed.mulPercentDown(bonusRate);
        // convert bonus from loan to collateral
        uint256 bonusCollateral = bonusByBorrowAssets.lendToCollateralUp(pos.price);

        uint256 newCollateral = pos.collateral - bonusCollateral;
        uint256 newShares = pos.borrowed.toSharesDown(0, 0);

        vm.prank(reallocator);
        vm.expectEmit(true, true, true, true, address(dahlia));
        vm.resumeGasMetering();
        emit Events.DahliaReallocate(
            $m1.marketId,
            $m2.marketId,
            reallocator,
            borrower,
            pos.borrowed,
            newShares,
            pos.collateral,
            newCollateral,
            bonusCollateral
        );
        dahlia.reallocate($m1.marketId, $m2.marketId, borrower);
        vm.pauseGasMetering();

        IDahlia.Market memory market1 = dahlia.getMarket($m1.marketId);
        IDahlia.Market memory market2 = dahlia.getMarket($m2.marketId);
        IDahlia.MarketUserPosition memory user1 = dahlia.getMarketUserPosition($m1.marketId, borrower);
        IDahlia.MarketUserPosition memory user2 = dahlia.getMarketUserPosition($m2.marketId, borrower);
        assertEq($m1.collateralToken.balanceOf(reallocator), bonusCollateral);
        assertEq($m2.collateralToken.balanceOf(address(dahlia)), pos.collateral - bonusCollateral);
        assertEq(user1.borrowShares, 0, "old position shares");
        assertEq(user1.collateral, 0, "old position collatera");
        assertEq(user2.borrowShares, newShares, "new position shares");
        assertEq(user2.collateral, newCollateral, "new position collateral");
        assertEq(market1.totalBorrowAssets, 0, "market1 total assets");
        assertEq(market1.totalBorrowShares, 0, "market1 total shares");
        assertEq(market2.totalBorrowAssets, pos.borrowed, "market2 total assets");
        assertEq(market2.totalBorrowShares, newShares, "market2 total shares");
    }

    function test_int_reallocate_healthyRevert(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $m1.marketConfig.rltv - 1);

        vm.dahliaSubmitPosition(pos, lender, borrower, $m1);

        uint256 positionLTV = dahlia.getPositionLTV($m1.marketId, $m1.alice);

        vm.prank(reallocator);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.HealthyPositionReallocation.selector, positionLTV, $m1.marketConfig.rltv)
        );
        dahlia.reallocate($m1.marketId, $m2.marketId, borrower);
        vm.pauseGasMetering();
    }

    function test_int_reallocate_badPositionRevert(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $m1.marketConfig.lltv + 1, TestConstants.MAX_TEST_LLTV);

        vm.dahliaSubmitPosition(pos, lender, borrower, $m1);

        uint256 positionLTV = dahlia.getPositionLTV($m1.marketId, $m1.alice);

        vm.prank(reallocator);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.BadPositionReallocation.selector, positionLTV, $m1.marketConfig.lltv)
        );
        dahlia.reallocate($m1.marketId, $m2.marketId, borrower);
        vm.pauseGasMetering();
    }

    function test_int_reallocate_insuffitiontLiquidityInMarket2(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $m1.marketConfig.rltv + 1, $m1.marketConfig.lltv - 1);
        vm.dahliaSubmitPosition(pos, lender, borrower, $m1);
        uint256 lentInMarket2 = bound(pos.borrowed, 1, pos.borrowed - 1);
        vm.dahliaLendBy(lender, lentInMarket2, $m2);

        vm.prank(reallocator);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientLiquidity.selector, pos.borrowed, lentInMarket2));
        dahlia.reallocate($m1.marketId, $m2.marketId, borrower);
        vm.pauseGasMetering();
    }
}
