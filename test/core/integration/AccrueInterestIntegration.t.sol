// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { console } from "@forge-std/console.sol";

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
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

        vm.resumeGasMetering();
        $.dahlia.accrueMarketInterest($.marketId);
        vm.pauseGasMetering();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.owner);
        IDahlia.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued, "total supply");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued, "total supply shares");
        assertEq(userPos.lendShares, 0, "feeRecipient's supply shares");
    }

    function test_int_accrueInterest_marketNotDeployed(IDahlia.MarketId marketIdFuzz) public {
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
        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;

        (uint256 interestEarnedAssets, uint256 newRatePerSec,) =
            $.marketConfig.irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);

        vm.forward(blocks);
        if (interestEarnedAssets > 0) {
            vm.expectEmit(true, true, true, true, address($.dahlia));
            emit Events.DahliaAccrueInterest($.marketId, newRatePerSec, interestEarnedAssets, 0, 0);
        }

        vm.resumeGasMetering();
        $.dahlia.accrueMarketInterest($.marketId);
        vm.pauseGasMetering();
        IDahlia.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalLendShares, state.totalLendShares, "total lend shares stay the same if no protocol fee");

        _checkInterestDidntChange();
    }

    function test_int_accrueInterest_withFees(TestTypes.MarketPosition memory pos, uint256 blocks, uint32 fee) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        uint32 protocolFee = uint32(bound(uint256(fee), BoundUtils.toPercent(2), BoundUtils.toPercent(5)));
        uint32 reserveFee = uint32(bound(uint256(fee), BoundUtils.toPercent(1), BoundUtils.toPercent(2)));

        vm.startPrank($.owner);
        if (protocolFee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, protocolFee);
        }
        if (reserveFee != $.dahlia.getMarket($.marketId).reserveFeeRate) {
            $.dahlia.setReserveFeeRate($.marketId, reserveFee);
        }
        vm.stopPrank();

        blocks = vm.boundBlocks(blocks);

        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);
        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        uint256 deltaTime = blocks * TestConstants.BLOCK_TIME;
        (uint256 interestEarnedAssets, uint256 newRatePerSec,) =
            $.marketConfig.irm.calculateInterest(deltaTime, state.totalLendAssets, state.totalBorrowAssets, state.fullUtilizationRate);

        uint256 protocolFeeShares = InterestImpl.calcFeeSharesFromInterest(state.totalLendAssets, state.totalLendShares, interestEarnedAssets, protocolFee);
        uint256 reserveFeeShares = InterestImpl.calcFeeSharesFromInterest(state.totalLendAssets, state.totalLendShares, interestEarnedAssets, reserveFee);

        vm.forward(blocks);
        if (interestEarnedAssets > 0) {
            vm.expectEmit(true, true, true, true, address($.dahlia));
            emit Events.DahliaAccrueInterest($.marketId, newRatePerSec, interestEarnedAssets, protocolFeeShares, reserveFeeShares);
        }

        $.dahlia.accrueMarketInterest($.marketId);

        IDahlia.Market memory stateAfter = $.dahlia.getMarket($.marketId);
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued + interestEarnedAssets, "total supply");
        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued + interestEarnedAssets, "total borrow");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued + protocolFeeShares + reserveFeeShares, "total lend shares");

        IDahlia.UserPosition memory userPos1 = $.dahlia.getPosition($.marketId, ctx.wallets("PROTOCOL_FEE_RECIPIENT"));
        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, ctx.wallets("RESERVE_FEE_RECIPIENT"));
        assertEq(userPos1.lendShares, protocolFeeShares, "protocolFeeRecipient's lend shares");
        assertEq(userPos.lendShares, reserveFeeShares, "reserveFeeRecipient's lend shares");
        if (interestEarnedAssets > 0) {
            assertEq(stateAfter.updatedAt, block.timestamp, "last update");
        }
    }

    function test_int_accrueInterest_getLastMarketStateWithFees(TestTypes.MarketPosition memory pos, uint256 blocks, uint32 fee) public {
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
        uint256 protocolFeeShares = InterestImpl.calcFeeSharesFromInterest(state.totalLendAssets, state.totalLendShares, interestEarnedAssets, fee);
        vm.forward(blocks);
        vm.resumeGasMetering();
        IDahlia.Market memory m = $.dahlia.getMarket($.marketId);

        assertEq(m.totalLendAssets, totalLendBeforeAccrued + interestEarnedAssets, "total supply");
        assertEq(m.totalBorrowAssets, totalBorrowBeforeAccrued + interestEarnedAssets, "total borrow");
        assertEq(m.totalLendShares, totalLendSharesBeforeAccrued + protocolFeeShares, "total supply shares");
        assertLt($.dahlia.previewLendRateAfterDeposit($.marketId, 0), $.dahlia.getMarket($.marketId).ratePerSec);
    }

    function printMarketState(string memory suffix, string memory title) public view {
        console.log("");
        console.log("#### BLOCK:", block.number, title);
        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);
        console.log(suffix, "market.totalLendAssets", state.totalLendAssets);
        console.log(suffix, "market.totalLendShares", state.totalLendShares);
        console.log(suffix, "market.totalBorrowShares", state.totalBorrowShares);
        console.log(suffix, "market.totalBorrowAssets", state.totalBorrowAssets);
        console.log(suffix, "market.utilization", state.totalBorrowAssets * 100_000 / state.totalLendAssets);
        console.log(suffix, "dahlia.usdc.balance", $.loanToken.balanceOf(address($.dahlia)));
        printUserPos(string.concat(suffix, " carol"), $.carol);
        printUserPos(string.concat(suffix, " bob"), $.bob);
    }

    function printUserPos(string memory suffix, address user) public view {
        IDahlia.UserPosition memory pos = $.dahlia.getPosition($.marketId, user);
        console.log(suffix, ".lendAssets", pos.lendAssets);
        console.log(suffix, ".lendShares", pos.lendShares);
        console.log(suffix, ".usdc.balance", $.loanToken.balanceOf(user));
    }

    function validateUserPos(string memory suffix, uint256 expectedBob, uint256 expectedCarol, uint256 expectedBobAssets, uint256 expectedCarolAssets)
        public
        view
    {
        (uint256 bobAssetsInterest, uint256 bobSharesInterest) = $.dahlia.getPositionInterest($.marketId, $.bob);
        assertEq(bobSharesInterest, expectedBob, string(abi.encodePacked("block ", block.number.toString(), " bob:", suffix)));
        assertEq(bobAssetsInterest, expectedBobAssets, string(abi.encodePacked("block ", block.number.toString(), " bob:", suffix)));
        (uint256 carolAssetsInterest, uint256 carolSharesInterest) = $.dahlia.getPositionInterest($.marketId, $.carol);
        assertEq(carolSharesInterest, expectedCarol, string(abi.encodePacked("carol:", suffix)));
        assertEq(carolAssetsInterest, expectedCarolAssets, string(abi.encodePacked("carol:", suffix)));
    }

    function test_previewLendRateAfterDeposit_wrong_market() public view {
        assertEq($.dahlia.previewLendRateAfterDeposit(IDahlia.MarketId.wrap(0), 0), 0);
    }

    function test_previewLendRateAfterDeposit_no_borrow_position() public view {
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 0);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 100_000), 0);
    }

    // use `forge test -vv --mt test_int_accrueInterest_Test1`
    function test_int_accrueInterest_Test1() public {
        vm.pauseGasMetering();
        TestTypes.MarketPosition memory pos = TestTypes.MarketPosition({
            collateral: 10_000e8,
            lent: 10_000e6,
            borrowed: 1000e6, // 10%
            price: 1e34,
            ltv: BoundUtils.toPercent(80)
        });
        uint32 protocolFee = BoundUtils.toPercent(0);
        uint32 reserveFee = BoundUtils.toPercent(0);
        $.oracle.setPrice(pos.price);
        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaLendBy($.bob, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);
        vm.dahliaBorrowBy($.alice, pos.borrowed, $);
        uint256 ltv = $.dahlia.getPositionLTV($.marketId, $.alice);
        console.log("ltv: ", ltv);
        console.log("usdc.decimals(): ", $.loanToken.decimals());
        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        WrappedVault vault = WrappedVault(address(market.vault));
        vm.prank(vault.owner());
        vault.addRewardsToken(address($.loanToken));

        vm.startPrank($.owner);
        if (protocolFee != $.dahlia.getMarket($.marketId).protocolFeeRate) {
            $.dahlia.setProtocolFeeRate($.marketId, protocolFee);
        }
        if (reserveFee != $.dahlia.getMarket($.marketId).reserveFeeRate) {
            $.dahlia.setReserveFeeRate($.marketId, reserveFee);
        }
        vm.stopPrank();
        printMarketState("0", "carol and bob has equal position with 10% ltv");
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 7_912_352, "initial lend rate");
        validateUserPos("0", 0, 0, 0, 0);

        vm.forward(1);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 8_750_130, "rate after 1 block");

        uint256 blocks = 100;
        vm.forward(blocks - 1);
        validateUserPos("1 ", 8_500_000, 8_500_000, 8, 8);
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, 0), 8_750_130, "lend rate after 100 blocks");
        assertEq($.dahlia.previewLendRateAfterDeposit($.marketId, pos.lent), 8_470_815, "lend rate if deposit more assets");
        vm.dahliaClaimInterestBy($.carol, $);
        validateUserPos("1 claim by carol", 8_750_000, 250_000, 8, 0);
        assertEq($.dahlia.getMarket($.marketId).ratePerSec, 175_002_615);
        assertLt($.dahlia.previewLendRateAfterDeposit($.marketId, pos.lent), $.dahlia.getMarket($.marketId).ratePerSec);
        printMarketState("1", "interest claimed by carol after 100 blocks");
        vm.dahliaClaimInterestBy($.carol, $);
        printMarketState("1.1", "interest again claimed by carol after 100 blocks");

        vm.forward(blocks / 2); // 50 block pass
        validateUserPos("1.2", 12_875_000, 4_125_000, 12, 4);
        vm.dahliaClaimInterestBy($.carol, $);
        printMarketState("1.2", "interest claimed by carol");
        validateUserPos("1.2 claim by carol", 12_937_500, 62_500, 12, 0);
        vm.dahliaClaimInterestBy($.bob, $);
        validateUserPos("1.3 claim by bob and carol", 468_750, 531_250, 0, 0);
        printMarketState("1.3", "interest claimed by bob");
        printMarketState("2", "accrual of interest and lending again by carol");
        vm.dahliaLendBy($.carol, pos.lent, $);
        validateUserPos("3 lending by carol", 468_750, 531_250, 0, 0);
        printMarketState("3", "carol lending again");
        //        vm.dahliaLendBy($.bob, pos.lent, $);
        //        printMarketState("4.1", "bob lending again");
        uint256 assets = vm.dahliaWithdrawBy($.bob, $.dahlia.getPosition($.marketId, $.bob).lendShares, $);
        validateUserPos("4 after bob withdraw all shares", 0, 1_000_000, 0, 1);
        printMarketState("4", "after bob withdraw all shares");
        console.log("4 bob assets withdrawn: ", assets);
        vm.dahliaWithdrawBy($.carol, $.dahlia.getPosition($.marketId, $.carol).lendShares / 2, $);
        validateUserPos("5 carol withdraw 1/2 of shares", 0, 1_000_000, 0, 1);
        printMarketState("5", "carol withdraw 1/2 of shares");
        vm.dahliaClaimInterestBy($.carol, $);
        validateUserPos("5 carol claim interest", 0, 0, 0, 0);
        printMarketState("5.1", "interest claimed by carol and 1/2 of shares withdrawn");
        IDahlia.UserPosition memory alicePos = $.dahlia.getPosition($.marketId, $.alice);
        vm.dahliaRepayByShares($.alice, alicePos.borrowShares, $.dahlia.getMarket($.marketId).totalBorrowAssets, $);
        validateUserPos("6 repay by alice", 0, 0, 0, 0);
        printMarketState("6", "repay by alice");
        vm.forward(blocks);
        uint256 assets2 = vm.dahliaWithdrawBy($.carol, $.dahlia.getPosition($.marketId, $.carol).lendShares, $);
        validateUserPos("8 carol withdraw all shares", 0, 0, 0, 0);
        printMarketState("8", "after carol withdraw all shares");
        console.log("8 carol assets withdrawn: ", assets2);
        vm.startPrank($.carol);
        // if not position claim will fail with NotPermitted
        // vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, address(market.vault)));
        market.vault.claim($.carol, address($.loanToken));
    }
}
