// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Vm } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { Constants, TestConstants, TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";
import { DahliaTest } from "test/common/abstracts/DahliaTest.sol";
import { ERC20Mock, IERC20 } from "test/common/mocks/ERC20Mock.sol";
import { OracleMock } from "test/common/mocks/OracleMock.sol";

contract StaleMarketIntegrationTest is DahliaTest {
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext ctx;
    TestContext.MarketContext $;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_staleMarket_marketNotDeployed(IDahlia.MarketId marketIdFuzz) public {
        vm.pauseGasMetering();
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.startPrank($.owner);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        vm.resumeGasMetering();
        $.dahlia.staleMarket(marketIdFuzz);
    }

    function test_int_staleMarket_marketDeprecated() public {
        vm.pauseGasMetering();
        vm.startPrank($.owner);
        $.dahlia.deprecateMarket($.marketId);

        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        vm.resumeGasMetering();
        $.dahlia.staleMarket($.marketId);
    }

    function test_int_staleMarket_unauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.staleMarket($.marketId);
    }

    function test_int_staleMarket_marketNoBadOracle() public {
        vm.pauseGasMetering();
        vm.startPrank($.owner);
        vm.expectRevert(Errors.OraclePriceNotStalled.selector);
        vm.resumeGasMetering();
        $.dahlia.staleMarket($.marketId);
    }

    function test_int_staleMarket_ActiveMarket_success() public {
        vm.pauseGasMetering();
        OracleMock($.oracle).setIsOracleBadData(true);

        assertEq(IDahlia.MarketStatus.Active, $.dahlia.getMarket($.marketId).status, "market is active");
        vm.startPrank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Active, IDahlia.MarketStatus.Stale);
        vm.resumeGasMetering();
        $.dahlia.staleMarket($.marketId);
        vm.pauseGasMetering();

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        assertEq(market.status, IDahlia.MarketStatus.Stale, "market is staled");
        assertEq(market.repayPeriodEndTimestamp, uint48(block.timestamp + $.dahliaRegistry.getValue(Constants.VALUE_ID_REPAY_PERIOD)));

        // disallow deprecate stalled market
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.deprecateMarket($.marketId);

        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.pauseMarket($.marketId);

        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.unpauseMarket($.marketId);
    }

    function test_int_staleMarket_pauseMarket_success() public {
        vm.pauseGasMetering();
        OracleMock($.oracle).setIsOracleBadData(true);

        vm.startPrank($.owner);

        $.dahlia.pauseMarket($.marketId);

        assertEq(IDahlia.MarketStatus.Pause, $.dahlia.getMarket($.marketId).status, "market is paused");

        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Pause, IDahlia.MarketStatus.Stale);
        vm.resumeGasMetering();
        $.dahlia.staleMarket($.marketId);
        vm.pauseGasMetering();

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        assertEq(market.status, IDahlia.MarketStatus.Stale, "market is staled");
        assertEq(market.repayPeriodEndTimestamp, uint48(block.timestamp + $.dahliaRegistry.getValue(Constants.VALUE_ID_REPAY_PERIOD)));
    }

    function staleMarket(IDahlia.MarketId id) internal {
        vm.pauseGasMetering();
        OracleMock($.oracle).setIsOracleBadData(true);
        vm.prank($.owner);
        vm.resumeGasMetering();
        $.dahlia.staleMarket(id);
    }

    function test_int_staleMarket_disallowBorrow(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        vm.dahliaLendBy($.carol, pos.lent, $);
        vm.dahliaSupplyCollateralBy($.alice, pos.collateral, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.prank($.alice);
        vm.expectRevert(Errors.MarketStalled.selector);
        vm.resumeGasMetering();
        $.dahlia.borrow($.marketId, pos.borrowed, $.alice, $.bob);
    }

    function test_int_staleMarket_disallowSupplyCollateral(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.prank($.alice);
        vm.expectRevert(Errors.MarketStalled.selector);
        vm.resumeGasMetering();
        $.dahlia.supplyCollateral($.marketId, pos.collateral, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_staleMarket_disallowLend(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        ERC20Mock($.marketConfig.loanToken).setBalance($.alice, pos.lent);

        vm.startPrank($.alice);
        IERC20($.marketConfig.loanToken).approve(address(market.vault), pos.lent);
        vm.expectRevert(Errors.MarketStalled.selector);
        vm.resumeGasMetering();
        market.vault.deposit(pos.lent, $.alice);
    }

    function test_int_staleMarket_disallowWithdrawLent(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        uint256 lendShares = $.dahlia.getPosition($.marketId, $.carol).lendShares;
        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);

        vm.startPrank($.carol);
        vm.expectRevert(Errors.MarketStalled.selector);
        vm.resumeGasMetering();
        market.vault.redeem(lendShares, $.carol, $.carol);
    }

    function test_int_staleMarket_disallowWithdrawCollateralWithoutRepay(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.prank($.alice);
        vm.expectRevert(Errors.OraclePriceBadData.selector);
        vm.resumeGasMetering();
        $.dahlia.withdrawCollateral($.marketId, pos.collateral, $.alice, $.alice);
    }

    function test_int_staleMarket_disallowLiquidate(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, $.marketConfig.lltv + 1, TestConstants.MAX_TEST_LLTV);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.expectRevert(Errors.MarketStalled.selector);
        vm.resumeGasMetering();
        $.dahlia.liquidate($.marketId, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_staleMarket_repayAndWithdraw(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.startPrank($.alice);
        $.loanToken.approve(address($.dahlia), pos.borrowed);
        vm.resumeGasMetering();
        $.dahlia.repay($.marketId, pos.borrowed, 0, $.alice, TestConstants.EMPTY_CALLBACK);
        $.dahlia.withdrawCollateral($.marketId, pos.collateral, $.alice, $.alice);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.alice);
        assertEq(userPos.borrowShares, 0, "position borrow shares balance");
        assertEq(userPos.collateral, 0, "position collateral balance");
        assertEq($.collateralToken.balanceOf($.alice), pos.collateral, "user collateral token balance");
        assertEq($.collateralToken.balanceOf(address($.dahlia)), 0, "Dahlia collateral token balance");
    }

    function test_int_staleMarket_disallowWithdrawNotStaled(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.startPrank($.alice);
        vm.expectRevert(Errors.MarketNotStalled.selector);
        vm.resumeGasMetering();
        $.dahlia.withdrawDepositAndClaimCollateral($.marketId, $.alice, $.alice);
    }

    function test_int_staleMarket_disallowWithdrawRepayPeriodNotEnded(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        vm.startPrank($.alice);
        vm.expectRevert(Errors.RepayPeriodNotEnded.selector);
        vm.resumeGasMetering();
        $.dahlia.withdrawDepositAndClaimCollateral($.marketId, $.alice, $.alice);
    }

    function calcMarketClaims(IDahlia.MarketId id, address user) internal view returns (uint256 lendAssets, uint256 collateralAssets, uint256 shares) {
        IDahlia.Market memory market = $.dahlia.getMarket(id);
        IDahlia.UserPosition memory lenderPosition = $.dahlia.getPosition(id, user);
        shares = uint256(lenderPosition.lendShares);

        // calculate owner assets based on liquidity in the market
        lendAssets = shares.toAssetsDown(market.totalLendAssets - market.totalBorrowAssets, market.totalLendShares);
        // calculate owed collateral based on lend shares
        collateralAssets = shares.toAssetsDown(market.totalCollateralAssets, market.totalLendShares);
    }

    function test_int_staleMarket_withdrawRepayPeriodEnded(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        uint256 repayPeriod = $.dahliaRegistry.getValue(Constants.VALUE_ID_REPAY_PERIOD);
        vm.warp(block.timestamp + repayPeriod);

        (uint256 lendAssets, uint256 collateralAssets, uint256 shares) = calcMarketClaims($.marketId, $.carol);

        vm.startPrank($.carol);
        emit IDahlia.WithdrawDepositAndClaimCollateral($.marketId, $.carol, $.carol, $.carol, lendAssets, collateralAssets, shares);
        vm.resumeGasMetering();
        $.dahlia.withdrawDepositAndClaimCollateral($.marketId, $.carol, $.carol);
        vm.pauseGasMetering();

        IDahlia.UserPosition memory carolPosition = $.dahlia.getPosition($.marketId, $.carol);
        assertEq(carolPosition.lendShares, 0, "position lend shares balance");
        assertEq(carolPosition.lendPrincipalAssets, 0, "position lend assets balance");
        assertEq($.collateralToken.balanceOf($.carol), collateralAssets, "carol collateral token balance");
        assertEq($.loanToken.balanceOf($.carol), lendAssets, "carol loan token balance");
    }

    function test_int_staleMarket_withdrawMultiRepayPeriodEnded(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        address maria = address(0x1);
        vm.dahliaLendBy(maria, pos.lent, $);

        vm.resumeGasMetering();
        staleMarket($.marketId);
        vm.pauseGasMetering();

        uint256 repayPeriod = $.dahliaRegistry.getValue(Constants.VALUE_ID_REPAY_PERIOD);
        vm.warp(block.timestamp + repayPeriod);

        // withdraw by carol
        (uint256 lendAssets, uint256 collateralAssets, uint256 shares) = calcMarketClaims($.marketId, $.carol);

        vm.startPrank($.carol);
        emit IDahlia.WithdrawDepositAndClaimCollateral($.marketId, $.carol, $.carol, $.carol, lendAssets, collateralAssets, shares);
        vm.resumeGasMetering();
        $.dahlia.withdrawDepositAndClaimCollateral($.marketId, $.carol, $.carol);
        vm.pauseGasMetering();

        IDahlia.UserPosition memory carolPosition = $.dahlia.getPosition($.marketId, $.carol);
        assertEq(carolPosition.lendShares, 0, "carol position lend shares balance");
        assertEq(carolPosition.lendPrincipalAssets, 0, "carol position lend principal balance");
        assertEq($.collateralToken.balanceOf($.carol), collateralAssets, "carol collateral token balance");
        assertEq($.loanToken.balanceOf($.carol), lendAssets, "carol loan token balance");

        // withdraw by maria
        vm.startPrank($.carol);

        (uint256 lendAssetsMaria, uint256 collateralAssetsMaria, uint256 sharesMaria) = calcMarketClaims($.marketId, maria);

        emit IDahlia.WithdrawDepositAndClaimCollateral($.marketId, maria, maria, maria, lendAssetsMaria, collateralAssetsMaria, sharesMaria);
        vm.resumeGasMetering();
        $.dahlia.withdrawDepositAndClaimCollateral($.marketId, maria, maria);
        vm.pauseGasMetering();

        IDahlia.UserPosition memory mariaPosition = $.dahlia.getPosition($.marketId, maria);
        assertEq(mariaPosition.lendShares, 0, "maria position lend shares balance");
        assertEq($.collateralToken.balanceOf(maria), collateralAssetsMaria, "maria collateral token balance");
        assertEq($.loanToken.balanceOf(maria), lendAssetsMaria, "maria loan token balance");
    }
}
