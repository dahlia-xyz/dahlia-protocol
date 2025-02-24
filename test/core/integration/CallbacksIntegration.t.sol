// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm, console } from "@forge-std/Test.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahliaLiquidateCallback, IDahliaRepayCallback, IDahliaSupplyCollateralCallback } from "src/core/interfaces/IDahliaCallbacks.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants } from "test/common/TestConstants.sol";
import { TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

contract CallbacksIntegrationTest is Test, IDahliaLiquidateCallback, IDahliaRepayCallback, IDahliaSupplyCollateralCallback {
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
        bytes4 selector = abi.decode(data, (bytes4));
        if (selector == this.test_int_callback_supplyCollateral.selector) {
            $.collateralToken.approve(address($.dahlia), amount);
        }
    }

    function onDahliaRepay(uint256 amount, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector = abi.decode(data, (bytes4));
        if (selector == this.test_int_callback_repay.selector) {
            $.loanToken.approve(address($.dahlia), amount);
        }
    }

    function onDahliaLiquidate(uint256 repaid, bytes memory data) external {
        assertEq(msg.sender, address($.dahlia));
        bytes4 selector = abi.decode(data, (bytes4));
        if (selector == this.test_int_callback_liquidate.selector) {
            $.loanToken.approve(address($.dahlia), repaid);
        }
    }

    function test_int_callback_supplyCollateral(uint256 amount) public {
        vm.pauseGasMetering();
        amount = bound(amount, 1, TestConstants.MAX_COLLATERAL_ASSETS);

        $.collateralToken.setBalance(address(this), amount);

        vm.resumeGasMetering();
        vm.expectRevert();
        $.dahlia.supplyCollateral($.marketId, amount, address(this), TestConstants.EMPTY_CALLBACK);

        $.dahlia.supplyCollateral($.marketId, amount, address(this), abi.encode(this.test_int_callback_supplyCollateral.selector));

        assertEq($.collateralToken.balanceOf(address($.dahlia)), amount);
    }

    function test_int_callback_repay(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, address(this), $);

        // Check revert if approvement is 0
        $.loanToken.approve(address($.dahlia), 0);

        vm.resumeGasMetering();
        vm.expectRevert();
        $.dahlia.repay($.marketId, pos.borrowed, 0, address(this), TestConstants.EMPTY_CALLBACK);

        // Check success by callback approvement
        $.dahlia.repay($.marketId, pos.borrowed, 0, address(this), abi.encode(this.test_int_callback_repay.selector));
    }

    function test_int_callback_liquidate(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        uint256 minLtv = $.marketConfig.lltv + 1;
        uint256 maxLtv = minLtv + MarketMath.mulPercentUp(Constants.LLTV_100_PERCENT - minLtv, $.dahlia.getMarket($.marketId).liquidationBonusRate);
        console.log("Market LLTV", $.marketConfig.lltv);
        console.log("liquidationBonusRate", $.dahlia.getMarket($.marketId).liquidationBonusRate);
        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, maxLtv);
        vm.dahliaSubmitPosition(pos, $.carol, address(this), $);

        $.loanToken.setBalance(address(this), pos.lent);

        // Check revert if approvement is 0
        $.loanToken.approve(address($.dahlia), 0);

        uint256 userBorrowShares = $.dahlia.getPosition($.marketId, address(this)).borrowShares;
        vm.resumeGasMetering();
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        $.dahlia.liquidate($.marketId, address(this), userBorrowShares, 0, TestConstants.EMPTY_CALLBACK);
        // Check success by callback approvement
        $.dahlia.liquidate($.marketId, address(this), userBorrowShares, 0, abi.encode(this.test_int_callback_liquidate.selector));
    }
}
