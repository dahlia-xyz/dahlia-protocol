// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Events} from "src/core/helpers/Events.sol";

import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract ReallocationIntegration is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $m1;
    TestContext.MarketContext $m2;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $m1 = ctx.bootstrapMarket("USDC", "WBTC", 0.7e5, 0.8e5);
        $m2 = ctx.bootstrapMarket(ctx.copyMarketConfig($m1.marketConfig, 0.8e5, 0.9e5));
    }

    function test_int_reallocate_1(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $m1.marketConfig.rltv + 1, $m1.marketConfig.lltv - 1);
        address borrower = $m1.alice;
        address lender = $m1.carol;
        address reallocator = $m1.bob;
        IDahlia dahlia = $m1.dahlia;

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

        Types.Market memory market1 = dahlia.getMarket($m1.marketId);
        Types.Market memory market2 = dahlia.getMarket($m2.marketId);
        (, uint256 borrowSharesM1, uint256 collateralM1) = dahlia.marketUserPositions($m1.marketId, borrower);
        (, uint256 borrowSharesM2, uint256 collateralM2) = dahlia.marketUserPositions($m2.marketId, borrower);
        assertEq($m1.collateralToken.balanceOf(reallocator), bonusCollateral);
        assertEq($m2.collateralToken.balanceOf(address(dahlia)), pos.collateral - bonusCollateral);
        assertEq(borrowSharesM1, 0, "old position shares");
        assertEq(collateralM1, 0, "old position collatera");
        assertEq(borrowSharesM2, newShares, "new position shares");
        assertEq(collateralM2, newCollateral, "new position collatera");
        assertEq(market1.totalBorrowAssets, 0, "market1 total assets");
        assertEq(market1.totalBorrowShares, 0, "market1 total shares");
        assertEq(market2.totalBorrowAssets, pos.borrowed, "market2 total assets");
        assertEq(market2.totalBorrowShares, newShares, "market2 total shares");
    }
}
