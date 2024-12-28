// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants, TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

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
        vm.expectRevert(abi.encodeWithSelector(Errors.WrongStatus.selector, IDahlia.MarketStatus.Uninitialized));
        $.dahlia.borrow(marketIdFuzz, assets, $.alice, $.alice);
    }

    function test_int_borrow_zeroAmount() public {
        //        vm.expectRevert(Errors.InconsistentAssetsOrSharesInput.selector);
        vm.prank($.alice);
        $.dahlia.borrow($.marketId, 0, $.alice, $.alice);
    }

    function test_int_borrow_zeroAddress(uint256 assets) public {
        vm.startPrank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, $.alice));
        $.dahlia.borrow($.marketId, assets, address(0), $.alice);

        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.borrow($.marketId, assets, $.alice, address(0));
        vm.stopPrank();
    }

    function test_int_borrow_unauthorized(TestTypes.MarketPosition memory pos, address supplier, address attacker) public {
        vm.pauseGasMetering();

        vm.assume(supplier != attacker && supplier != address(0));
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        vm.dahliaLendBy($.alice, pos.lent, $);
        vm.dahliaSupplyCollateralBy(supplier, pos.collateral, $);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, attacker));
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, supplier, attacker);
    }

    function test_int_borrow_unhealthyPosition(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, BoundUtils.toPercent(100), BoundUtils.toPercent(150));

        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);

        (, uint256 maxBorrowAssets, uint256 collateralPrice) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice);
        assertEq(collateralPrice, pos.price);

        vm.prank($.alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientCollateral.selector, pos.borrowed, maxBorrowAssets));
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, $.alice, $.alice);
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
        $.dahlia.borrow($.marketId, pos.borrowed, $.alice, $.alice);
    }

    function test_int_getMaxBorrowableAmount(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();

        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        $.oracle.setPrice(pos.price);

        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);
        (uint256 borrowAssets1, uint256 maxBorrowAssets1,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice);
        assertEq(borrowAssets1, 0, "no borrowed assets yet");
        assertEq(maxBorrowAssets1, 0, "user can not borrow because no lending assets");

        vm.dahliaLendBy($.carol, 1, $);
        (uint256 borrowAssets2, uint256 maxBorrowAssets2,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice);
        assertEq(borrowAssets2, 0, "borrowAssets2 no borrowed assets yet");
        assertEq(maxBorrowAssets2, 1, "user can borrow 1 asset only");

        vm.dahliaLendBy($.carol, pos.lent - 1, $);

        (uint256 borrowAssets3, uint256 maxBorrowAssets3,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice);
        assertEq(borrowAssets3, 0, "borrowAssets3 no borrowed assets yet");
        assertLe(maxBorrowAssets3, pos.lent, "user can borrow but still less then pos.lent");

        uint256 expectedBorrowShares = pos.borrowed.toSharesUp(0, 0);

        vm.startPrank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.DahliaBorrow($.marketId, $.alice, $.alice, $.bob, pos.borrowed, expectedBorrowShares);
        vm.resumeGasMetering();
        uint256 _shares = $.dahlia.borrow($.marketId, pos.borrowed, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        (uint256 borrowAssets4, uint256 maxBorrowAssets4,) = $.dahlia.getMaxBorrowableAmount($.marketId, $.alice);
        assertEq(borrowAssets4, pos.borrowed, "already borrowed asset");
        assertEq(expectedBorrowShares, _shares, "check shares");
        assertEq(maxBorrowAssets4, maxBorrowAssets3 - borrowAssets4, "still can borrow");
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
        emit IDahlia.DahliaBorrow($.marketId, $.alice, $.alice, $.bob, pos.borrowed, expectedBorrowShares);
        vm.resumeGasMetering();
        uint256 _shares = $.dahlia.borrow($.marketId, pos.borrowed, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        _checkMarketBorrowValid(pos.borrowed, _shares, pos.lent, pos.borrowed, expectedBorrowShares);
    }

    function _checkMarketBorrowValid(uint256 returnAssets, uint256 returnShares, uint256 amountLent, uint256 amountBorrowed, uint256 expectedBorrowShares)
        internal
        view
    {
        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.alice);
        assertEq(returnAssets, amountBorrowed, "returned asset amount");
        assertEq(returnShares, expectedBorrowShares, "returned shares amount");
        assertEq($.dahlia.getMarket($.marketId).totalBorrowAssets, amountBorrowed, "total borrow");
        assertEq(userPos.borrowShares, expectedBorrowShares, "borrow share");
        assertEq($.loanToken.balanceOf($.bob), amountBorrowed, "receiver balance");
        assertEq($.loanToken.balanceOf(address($.vault)), amountLent - amountBorrowed, "dahlia balance");
    }
}
