// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {InterestImpl} from "src/core/impl/InterestImpl.sol";
import {Types} from "src/core/types/Types.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract AccrueInterestIntegrationTest is Test {
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

    function _checkInterestDidntChange() internal {
        vm.pauseGasMetering();
        Types.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        vm.resumeGasMetering();
        $.dahlia.accrueMarketInterest($.marketId);
        vm.pauseGasMetering();

        Types.MarketUserPosition memory userPos = $.dahlia.getMarketUserPosition($.marketId, $.owner);
        Types.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued, "total supply");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued, "total supply shares");
        assertEq(userPos.lendShares, 0, "feeRecipient's supply shares");
    }

    function test_int_accrueInterest_marketNotDeployed(Types.MarketId marketIdFuzz) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.resumeGasMetering();
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.accrueMarketInterest(marketIdFuzz);
    }

    function test_int_accrueInterest_zeroIrm() public {
        vm.pauseGasMetering();
        $.marketConfig.irm = IIrm(address(0));
        vm.resumeGasMetering();
        $.dahlia.accrueMarketInterest($.marketId);
        _checkInterestDidntChange();
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

    function test_int_accrueInterest_noFee(TestTypes.MarketPosition memory pos, uint256 blocks) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        blocks = vm.boundBlocks(blocks);
        vm.forward(blocks);

        Types.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;

        IIrm irm = ctx.createTestIrm();
        (uint256 interestEarnedAssets, uint256 newRatePerSec,) =
            irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);

        if (interestEarnedAssets > 0) {
            vm.expectEmit(true, true, true, true, address($.dahlia));
            emit Events.DahliaAccrueInterest($.marketId, newRatePerSec, interestEarnedAssets, 0, 0);
        }

        vm.resumeGasMetering();
        $.dahlia.accrueMarketInterest($.marketId);
        vm.pauseGasMetering();
        Types.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(
            stateAfter.totalLendShares, state.totalLendShares, "total lend shares stay the same if no protocol fee"
        );

        _checkInterestDidntChange();
    }

    function test_int_accrueInterest_withFees(TestTypes.MarketPosition memory pos, uint256 blocks, uint32 fee) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        uint32 protocolFee = uint32(bound(uint256(fee), MarketMath.toPercent(2), MarketMath.toPercent(5)));
        uint32 reserveFee = uint32(bound(uint256(fee), MarketMath.toPercent(1), MarketMath.toPercent(2)));

        vm.startPrank($.owner);
        if (protocolFee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, protocolFee);
        }
        if (reserveFee != $.dahlia.getMarket($.marketId).reserveFeeRate) {
            $.dahlia.setReserveFeeRate($.marketId, reserveFee);
        }
        vm.stopPrank();

        blocks = vm.boundBlocks(blocks);
        vm.forward(blocks);

        Types.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;
        IIrm irm = ctx.createTestIrm();
        (uint256 interestEarnedAssets, uint256 newRatePerSec,) =
            irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);

        uint256 protocolFeeShares = InterestImpl.calcFeeSharesFromInterest(
            state.totalLendAssets, state.totalLendShares, interestEarnedAssets, protocolFee
        );
        uint256 reserveFeeShares = InterestImpl.calcFeeSharesFromInterest(
            state.totalLendAssets, state.totalLendShares, interestEarnedAssets, reserveFee
        );

        if (interestEarnedAssets > 0) {
            vm.expectEmit(true, true, true, true, address($.dahlia));
            emit Events.DahliaAccrueInterest(
                $.marketId, newRatePerSec, interestEarnedAssets, protocolFeeShares, reserveFeeShares
            );
        }

        $.dahlia.accrueMarketInterest($.marketId);

        Types.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued + interestEarnedAssets, "total supply");
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued + interestEarnedAssets, "total borrow");
        assertEq(
            stateAfter.totalLendShares,
            totalLendSharesBeforeAccrued + protocolFeeShares + reserveFeeShares,
            "total lend shares"
        );

        Types.MarketUserPosition memory userPos1 =
            $.dahlia.getMarketUserPosition($.marketId, ctx.wallets("PROTOCOL_FEE_RECIPIENT"));
        Types.MarketUserPosition memory userPos =
            $.dahlia.getMarketUserPosition($.marketId, ctx.wallets("RESERVE_FEE_RECIPIENT"));
        assertEq(userPos1.lendShares, protocolFeeShares, "protocolFeeRecipient's lend shares");
        assertEq(userPos.lendShares, reserveFeeShares, "reserveFeeRecipient's lend shares");
        if (interestEarnedAssets > 0) {
            assertEq(stateAfter.updatedAt, block.timestamp, "last update");
        }
    }

    function test_int_accrueInterest_getLastMarketStateWithFees(
        TestTypes.MarketPosition memory pos,
        uint256 blocks,
        uint32 fee
    ) public {
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
        vm.forward(blocks);

        Types.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;
        IIrm irm = ctx.createTestIrm();

        vm.resumeGasMetering();
        (uint256 interestEarnedAssets,,) =
            irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);

        uint256 protocolFeeShares = InterestImpl.calcFeeSharesFromInterest(
            state.totalLendAssets, state.totalLendShares, interestEarnedAssets, fee
        );
        vm.pauseGasMetering();

        (uint256 totalLendAssets, uint256 totalLendShares, uint256 totalBorrowAssets,,,) =
            $.dahlia.getLastMarketState($.marketId);

        assertEq(totalLendAssets, totalLendBeforeAccrued + interestEarnedAssets, "total supply");
        assertEq(totalBorrowAssets, totalBorrowBeforeAccrued + interestEarnedAssets, "total borrow");
        assertEq(totalLendShares, totalLendSharesBeforeAccrued + protocolFeeShares, "total supply shares");
    }
}
