// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants, TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

contract AccrueInterestIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;
    using LibString for uint256;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function _checkInterestDidntChange() internal {
        vm.pauseGasMetering();
        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.owner);
        IDahlia.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued, "total supply");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued, "total supply shares");
        assertEq(userPos.lendShares, 0, "feeRecipient's supply shares");
    }

    function test_int_accrueInterest_noTimeElapsed(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);
        _checkInterestDidntChange();
    }

    function test_int_accrueInterest_noBorrow(uint256 amountLent, uint256 blocks) public {
        vm.pauseGasMetering();
        amountLent = bound(amountLent, 2, TestConstants.MAX_TEST_AMOUNT);
        blocks = vm.boundBlocks(blocks);

        vm.dahliaLendBy($.carol, amountLent, $);
        vm.forward(blocks);
        _checkInterestDidntChange();
    }

    function test_int_accrueInterest_getLatestMarketStateWithFees(TestTypes.MarketPosition memory pos, uint256 blocks, uint32 fee) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        fee = uint32(bound(uint256(fee), 1, Constants.MAX_FEE_RATE));

        vm.startPrank($.owner);
        if (fee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, fee);
        }
        vm.stopPrank();

        blocks = vm.boundBlocks(blocks);

        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;
        (uint256 interestEarnedAssets,,) =
            $.marketConfig.irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);
        uint256 protocolFeeAssets = interestEarnedAssets * state.protocolFeeRate / Constants.FEE_PRECISION;
        uint256 sumOfFeeAssets = protocolFeeAssets;
        uint256 sumOfFeeShares = sumOfFeeAssets.toSharesDown(state.totalLendAssets + interestEarnedAssets - sumOfFeeAssets, state.totalLendShares);

        uint256 protocolFeeShares = protocolFeeAssets.toSharesDown(state.totalLendAssets + interestEarnedAssets, state.totalLendShares + sumOfFeeShares);

        vm.forward(blocks);
        vm.resumeGasMetering();
        IDahlia.Market memory m = $.dahlia.getMarket($.marketId);

        assertEq(m.totalLendAssets, totalLendBeforeAccrued + interestEarnedAssets, "total supply");
        assertEq(m.totalBorrowAssets, totalBorrowBeforeAccrued + interestEarnedAssets, "total borrow");
        assertEq(m.totalLendShares, totalLendSharesBeforeAccrued + protocolFeeShares, "total supply shares");
        assertLt($.dahlia.previewLendRateAfterDeposit($.marketId, 0), $.dahlia.getMarket($.marketId).ratePerSec);
    }

    function test_previewLendRateAfterDeposit_wrong_market() public view {
        assertEq($.dahlia.previewLendRateAfterDeposit(IDahlia.MarketId.wrap(0), 0), 0);
    }

    function test_previewLendRateAfterDeposit_no_borrow_position() public view {
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 0);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 100_000), 0);
    }
}
