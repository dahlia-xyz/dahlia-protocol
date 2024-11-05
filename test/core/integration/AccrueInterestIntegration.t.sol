// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "@forge-std/console.sol";
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

        (uint256 lendShares,,) = $.dahlia.marketUserPositions($.marketId, $.owner);
        Types.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued, "total supply");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued, "total supply shares");
        assertEq(lendShares, 0, "feeRecipient's supply shares");
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

        (uint256 protocolFeeLendShares,,) =
            $.dahlia.marketUserPositions($.marketId, ctx.wallets("PROTOCOL_FEE_RECIPIENT"));
        (uint256 reserveFeeLendShares,,) =
            $.dahlia.marketUserPositions($.marketId, ctx.wallets("RESERVE_FEE_RECIPIENT"));
        assertEq(protocolFeeLendShares, protocolFeeShares, "protocolFeeRecipient's lend shares");
        assertEq(reserveFeeLendShares, reserveFeeShares, "reserveFeeRecipient's lend shares");
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

    function printUserPos(string memory suffix, address user) public {
        Types.MarketUserPosition memory pos = $.dahlia.getMarketUserPosition($.marketId, user);
        console.log(suffix, ".interestRateCheckpointed", pos.interestRateCheckpointed);
        console.log(suffix, ".interestAccumulated", pos.interestAccumulated);
    }

    function test_int_accrueInterest_Test1() public {
        vm.pauseGasMetering();
        TestTypes.MarketPosition memory pos = TestTypes.MarketPosition({
            collateral: 10000e8,
            lent: 10000e6,
            borrowed: 1000e6, // 10%
            price: 1e34,
            ltv: MarketMath.toPercent(80)
        });
        uint32 protocolFee = MarketMath.toPercent(2);
        uint32 reserveFee = MarketMath.toPercent(1);
        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaLendBy($.bob, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);
        vm.dahliaBorrowBy($.alice, pos.borrowed, $);
        uint256 ltv = $.dahlia.getPositionLTV($.marketId, $.alice);
        console.log("ltv: ", ltv);
        console.log("usdc.decimals(): ", $.loanToken.decimals());
        uint256 blocks = 100;

        vm.startPrank($.owner);
        if (protocolFee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, protocolFee);
        }
        if (reserveFee != $.dahlia.getMarket($.marketId).reserveFeeRate) {
            $.dahlia.setReserveFeeRate($.marketId, reserveFee);
        }
        vm.stopPrank();
        vm.forward(blocks);

        Types.Market memory state = $.dahlia.getMarket($.marketId);

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
        console.log("1 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("1 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("1 carol", $.carol);
        printUserPos("1 bob", $.bob);
        vm.forward(blocks);
        vm.dahliaLendBy($.carol, pos.lent, $);
        console.log("2 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("2 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("2 carol", $.carol);
        printUserPos("2 bob", $.bob);
        console.log("2 bob.interestAccumulated", $.dahlia.getMarketUserPosition($.marketId, $.bob).interestAccumulated);
        vm.dahliaLendBy($.carol, pos.lent, $);
        console.log("3 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("3 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("3 carol", $.carol);
        printUserPos("3 bob", $.bob);
        $.dahlia.accrueMarketInterest($.marketId);
        console.log("4 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("4 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("4 carol", $.carol);
        printUserPos("4 bob", $.bob);
        vm.dahliaWithdrawBy($.bob, $.dahlia.getMarketUserPosition($.marketId, $.bob).lendShares, $);
        console.log("5 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("5 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("5 carol", $.carol);
        printUserPos("5 bob", $.bob);
        vm.forward(blocks);
        $.dahlia.accrueMarketInterest($.marketId);
        console.log("6 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("6 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        printUserPos("6 carol", $.carol);
        printUserPos("6 bob", $.bob);
        vm.dahliaWithdrawBy($.carol, $.dahlia.getMarketUserPosition($.marketId, $.carol).lendShares / 3, $);
        console.log("7 market.interestRateAccumulated", $.dahlia.getMarket($.marketId).interestRateAccumulated);
        console.log("7 market.totalLendAssets", $.dahlia.getMarket($.marketId).totalLendAssets);
        console.log(
            "7 carol.interestRateCheckpointed",
            $.dahlia.getMarketUserPosition($.marketId, $.carol).interestRateCheckpointed
        );
        console.log(
            "7 carol.interestAccumulated", $.dahlia.getMarketUserPosition($.marketId, $.carol).interestAccumulated
        );
        console.log(
            "7 bob.interestRateCheckpointed", $.dahlia.getMarketUserPosition($.marketId, $.bob).interestRateCheckpointed
        );
        console.log("7 bob.interestAccumulated", $.dahlia.getMarketUserPosition($.marketId, $.bob).interestAccumulated);
        console.log("7 bob.lendShares", $.dahlia.getMarketUserPosition($.marketId, $.bob).lendShares);
    }
}
