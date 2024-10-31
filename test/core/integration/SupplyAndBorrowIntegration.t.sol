// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract SupplyAndBorrowIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    uint256 nonce;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_supplyAndBorrow_marketNotDeployed(Types.MarketId marketIdFuzz, uint256 assets) public {
        vm.assume(assets > 0);
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.prank($.alice);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.supplyAndBorrow(marketIdFuzz, assets, assets, $.alice, $.alice);
    }

    function test_int_supplyAndBorrow_zeroAmount() public {
        vm.expectRevert(Errors.ZeroAssets.selector);
        vm.prank($.alice);
        $.dahlia.supplyAndBorrow($.marketId, 0, 0, $.alice, $.alice);

        vm.expectRevert(Errors.ZeroAssets.selector);
        vm.prank($.alice);
        $.dahlia.supplyAndBorrow($.marketId, 0, 1, $.alice, $.alice);

        vm.expectRevert(Errors.ZeroAssets.selector);
        vm.prank($.alice);
        $.dahlia.supplyAndBorrow($.marketId, 1, 0, $.alice, $.alice);
    }

    function test_int_supplyAndBorrow_zeroAddress(uint256 assets) public {
        vm.assume(assets > 0);
        vm.startPrank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, $.alice));
        $.dahlia.supplyAndBorrow($.marketId, assets, assets, address(0), $.alice);

        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.supplyAndBorrow($.marketId, assets, assets, $.alice, address(0));
        vm.stopPrank();
    }

    function test_int_supplyAndBorrow_unhealthyPosition(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, MarketMath.toPercent(100), MarketMath.toPercent(150));

        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaPrepareCollateralBalanceFor($.alice, pos.collateral, $);

        uint256 maxBorrowAssets = pos.collateral.collateralToLendUp(pos.price).mulPercentUp($.marketConfig.lltv);

        vm.prank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientCollateral.selector, pos.borrowed, maxBorrowAssets));
        vm.resumeGasMetering();
        $.dahlia.supplyAndBorrow($.marketId, pos.collateral, pos.borrowed, $.alice, $.alice);
    }

    function test_int_supplyAndBorrow_insufficientLiquidity(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.assume(pos.borrowed >= 10);

        // Make lend less then borrow
        pos.lent = bound(pos.lent, 1, pos.borrowed - 1);

        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaPrepareCollateralBalanceFor($.alice, pos.collateral, $);

        vm.prank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientLiquidity.selector, pos.borrowed, pos.lent));
        vm.resumeGasMetering();
        $.dahlia.supplyAndBorrow($.marketId, pos.collateral, pos.borrowed, $.alice, $.alice);
    }

    function test_int_supplyAndBorrow_byAssets(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaPrepareCollateralBalanceFor($.alice, pos.collateral, $);
        uint256 expectedBorrowShares = pos.borrowed.toSharesUp(0, 0);

        vm.startPrank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SupplyCollateral($.marketId, $.alice, $.alice, pos.collateral);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.DahliaBorrow($.marketId, $.alice, $.alice, $.bob, pos.borrowed, expectedBorrowShares);
        vm.resumeGasMetering();
        (uint256 _assets, uint256 _shares) =
            $.dahlia.supplyAndBorrow($.marketId, pos.collateral, pos.borrowed, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        _checkMarketBorrowValid(_assets, _shares, pos.lent, pos.borrowed, expectedBorrowShares);
    }

    function _checkMarketBorrowValid(
        uint256 returnAssets,
        uint256 returnShares,
        uint256 amountLent,
        uint256 amountBorrowed,
        uint256 expectedBorrowShares
    ) internal view {
        (, uint256 borrowShares,) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq(returnAssets, amountBorrowed, "returned asset amount");
        assertEq(returnShares, expectedBorrowShares, "returned shares amount");
        assertEq($.dahlia.getMarket($.marketId).totalBorrowAssets, amountBorrowed, "total borrow");
        assertEq(borrowShares, expectedBorrowShares, "borrow share");
        assertEq($.loanToken.balanceOf($.bob), amountBorrowed, "receiver balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), amountLent - amountBorrowed, "dahlia balance");
    }
}
