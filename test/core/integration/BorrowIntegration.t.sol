// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract BorrowIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    uint256 nonce;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_borrow_marketNotDeployed(IDahlia.MarketId marketIdFuzz, uint256 assets) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.prank($.alice);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.borrow(marketIdFuzz, assets, 0, $.alice, $.alice);
    }

    function test_int_borrow_zeroAmount() public {
        vm.expectRevert(Errors.InconsistentAssetsOrSharesInput.selector);
        vm.prank($.alice);
        $.dahlia.borrow($.marketId, 0, 0, $.alice, $.alice);

        vm.expectRevert(Errors.InconsistentAssetsOrSharesInput.selector);
        vm.prank($.alice);
        $.dahlia.borrow($.marketId, 1, 1, $.alice, $.alice);
    }

    function test_int_borrow_zeroAddress(uint256 assets) public {
        vm.startPrank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, $.alice));
        $.dahlia.borrow($.marketId, assets, 0, address(0), $.alice);

        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.borrow($.marketId, assets, 0, $.alice, address(0));
        vm.stopPrank();
    }

    function test_int_borrow_inconsistentInput(uint256 amount, uint256 shares) public {
        vm.pauseGasMetering();

        amount = vm.boundBlocks(amount);
        amount = vm.boundAmount(amount);
        shares = bound(shares, 1, TestConstants.MAX_TEST_SHARES);

        vm.prank($.alice);
        vm.expectRevert(Errors.InconsistentAssetsOrSharesInput.selector);
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, amount, shares, $.alice, $.alice);
    }

    function test_int_borrow_unauthorized(TestTypes.MarketPosition memory pos, address supplier, address attacker)
        public
    {
        vm.pauseGasMetering();

        vm.assume(supplier != attacker && supplier != address(0));
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        vm.dahliaLendBy($.alice, pos.lent, $);
        vm.dahliaSupplyCollateralBy(supplier, pos.collateral, $);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, attacker));
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, 0, supplier, attacker);
    }

    function test_int_borrow_unhealthyPosition(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, MarketMath.toPercent(100), MarketMath.toPercent(150));

        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);

        (, uint256 maxBorrowAssets, uint256 collateralPrice) = $.dahlia.marketUserMaxBorrows($.marketId, $.alice);
        assertEq(collateralPrice, pos.price);

        vm.prank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientCollateral.selector, pos.borrowed, maxBorrowAssets));
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, 0, $.alice, $.alice);
    }

    function test_int_borrow_insufficientLiquidity(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.assume(pos.borrowed >= 10);

        // Make lend less then borrow
        pos.lent = bound(pos.lent, 1, pos.borrowed - 1);

        vm.dahliaLendBy($.carol, pos.lent, $);

        $.oracle.setPrice(pos.price);

        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);

        vm.prank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientLiquidity.selector, pos.borrowed, pos.lent));
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, 0, $.alice, $.alice);
    }

    function test_int_borrow_byAssets(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaLendBy($.carol, pos.lent, $);
        $.oracle.setPrice(pos.price);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);
        uint256 expectedBorrowShares = pos.borrowed.toSharesUp(0, 0);

        vm.startPrank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.DahliaBorrow($.marketId, $.alice, $.alice, $.bob, pos.borrowed, expectedBorrowShares);
        vm.resumeGasMetering();
        (uint256 _assets, uint256 _shares) = $.dahlia.borrow($.marketId, pos.borrowed, 0, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        _checkMarketBorrowValid(_assets, _shares, pos.lent, pos.borrowed, expectedBorrowShares);
    }

    function test_int_borrow_byShares(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        uint256 sharesBorrowed = pos.borrowed.toSharesUp(0, 0);

        vm.dahliaLendBy($.carol, pos.lent, $);
        $.oracle.setPrice(pos.price);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);

        vm.startPrank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.DahliaBorrow($.marketId, $.alice, $.alice, $.bob, pos.borrowed, sharesBorrowed);
        vm.resumeGasMetering();
        (uint256 _assets, uint256 _shares) = $.dahlia.borrow($.marketId, 0, sharesBorrowed, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        _checkMarketBorrowValid(_assets, _shares, pos.lent, pos.borrowed, sharesBorrowed);
    }

    function _checkMarketBorrowValid(
        uint256 returnAssets,
        uint256 returnShares,
        uint256 amountLent,
        uint256 amountBorrowed,
        uint256 expectedBorrowShares
    ) internal view {
        IDahlia.MarketUserPosition memory userPos = $.dahlia.getMarketUserPosition($.marketId, $.alice);
        assertEq(returnAssets, amountBorrowed, "returned asset amount");
        assertEq(returnShares, expectedBorrowShares, "returned shares amount");
        assertEq($.dahlia.getMarket($.marketId).totalBorrowAssets, amountBorrowed, "total borrow");
        assertEq(userPos.borrowShares, expectedBorrowShares, "borrow share");
        assertEq($.loanToken.balanceOf($.bob), amountBorrowed, "receiver balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), amountLent - amountBorrowed, "dahlia balance");
    }
}
