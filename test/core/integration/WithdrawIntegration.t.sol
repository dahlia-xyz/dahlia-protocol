// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants} from "test/common/TestConstants.sol";
import {TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";

contract WithdrawIntegrationTest is Test {
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_withdraw_marketNotDeployed(Types.MarketId marketIdFuzz, uint256 assets) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.prank($.alice);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.withdraw(marketIdFuzz, assets, $.alice, $.alice);
    }

    function test_int_withdraw_zeroAmount() public {
        vm.pauseGasMetering();
        vm.dahliaLendBy($.alice, 1, $);

        vm.prank($.alice);
        vm.resumeGasMetering();
        uint256 assets = $.dahlia.withdraw($.marketId, 0, $.alice, $.alice);
        assertEq(assets, 0);
    }

    function test_int_withdraw_zeroAddress(uint256 lent) public {
        vm.pauseGasMetering();
        lent = vm.boundAmount(lent);
        vm.dahliaLendBy($.alice, lent, $);

        vm.resumeGasMetering();
        vm.startPrank($.alice);
        vm.expectRevert(Errors.NotPermitted.selector);
        $.dahlia.withdraw($.marketId, lent, address(0), $.alice);

        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.withdraw($.marketId, lent, $.alice, address(0));
        vm.stopPrank();
    }

    function test_int_withdraw_insufficientLiquidity(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.carol, $.alice, $);

        uint256 expectedSupplyShares = pos.lent.toSharesDown(0, 0);
        uint256 expectedWithdrawnShares = pos.lent.toSharesUp(pos.lent, expectedSupplyShares);

        // Carol cannot withdraw own assets, because alice already borrowed part
        vm.prank($.carol);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientLiquidity.selector, pos.borrowed, 0));
        $.dahlia.withdraw($.marketId, expectedWithdrawnShares, $.carol, $.carol);
    }

    function test_int_withdraw_byAssets(TestTypes.MarketPosition memory pos, uint256 amountWithdrawn) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.alice, $.carol, $);

        amountWithdrawn = bound(amountWithdrawn, 1, pos.lent - pos.borrowed);
        uint256 expectedSupplyShares = pos.lent.toSharesDown(0, 0);
        uint256 expectedWithdrawnShares = amountWithdrawn.toSharesUp(pos.lent, expectedSupplyShares);

        vm.prank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.Withdraw($.marketId, $.alice, $.alice, $.bob, amountWithdrawn, expectedWithdrawnShares);
        vm.resumeGasMetering();
        uint256 returnAssets = $.dahlia.withdraw($.marketId, expectedWithdrawnShares, $.alice, $.bob);
        vm.pauseGasMetering();

        expectedSupplyShares -= expectedWithdrawnShares;
        assertEq(returnAssets, amountWithdrawn, "returned asset amount");
        (uint256 lendShares,,) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq(lendShares, expectedSupplyShares, "lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendShares, expectedSupplyShares, "total lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendAssets, pos.lent - amountWithdrawn, "total supply");
        assertEq($.loanToken.balanceOf($.bob), amountWithdrawn, "receiver balance");
        assertEq($.loanToken.balanceOf($.carol), pos.borrowed, "borrower balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), pos.lent - pos.borrowed - amountWithdrawn, "Dahlia balance");
    }

    function test_int_withdraw_byShares(TestTypes.MarketPosition memory pos, uint256 sharesWithdrawn) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.alice, $.carol, $);

        uint256 expectedSupplyShares = pos.lent.toSharesDown(0, 0);
        uint256 availableLiquidity = pos.lent - pos.borrowed;
        uint256 withdrawableShares = availableLiquidity.toSharesDown(pos.lent, expectedSupplyShares);
        vm.assume(withdrawableShares != 0);

        sharesWithdrawn = bound(sharesWithdrawn, 1, withdrawableShares);
        uint256 expectedAmountWithdrawn = sharesWithdrawn.toAssetsDown(pos.lent, expectedSupplyShares);

        vm.prank($.alice);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.Withdraw($.marketId, $.alice, $.alice, $.bob, expectedAmountWithdrawn, sharesWithdrawn);
        vm.resumeGasMetering();
        uint256 returnAssets = $.dahlia.withdraw($.marketId, sharesWithdrawn, $.alice, $.bob);
        vm.pauseGasMetering();

        expectedSupplyShares -= sharesWithdrawn;
        assertEq(returnAssets, expectedAmountWithdrawn, "returned asset amount");
        (uint256 lendShares,,) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq(lendShares, expectedSupplyShares, "lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendAssets, pos.lent - expectedAmountWithdrawn, "total supply");
        assertEq($.dahlia.getMarket($.marketId).totalLendShares, expectedSupplyShares, "total lend shares");
        assertEq($.loanToken.balanceOf($.bob), expectedAmountWithdrawn, "receiver balance");
        assertEq(
            $.loanToken.balanceOf(address($.dahlia)),
            pos.lent - pos.borrowed - expectedAmountWithdrawn,
            "Dahlia balance"
        );
    }

    function test_int_withdraw_onBehalfOfByAssets(TestTypes.MarketPosition memory pos, uint256 amountWithdrawn)
        public
    {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.alice, $.carol, $);

        amountWithdrawn = bound(amountWithdrawn, 1, pos.lent - pos.borrowed);

        address ALICE_MONEY_MANAGER = makeAddr("ALICE_MONEY_MANAGER");
        vm.prank($.alice);
        $.dahlia.updatePermission(ALICE_MONEY_MANAGER, true);

        uint256 expectedSupplyShares = pos.lent.toSharesDown(0, 0);
        uint256 expectedWithdrawnShares = amountWithdrawn.toSharesUp(pos.lent, expectedSupplyShares);

        vm.prank(ALICE_MONEY_MANAGER);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.Withdraw($.marketId, ALICE_MONEY_MANAGER, $.alice, $.bob, amountWithdrawn, expectedWithdrawnShares);
        vm.resumeGasMetering();
        uint256 returnAssets = $.dahlia.withdraw($.marketId, expectedWithdrawnShares, $.alice, $.bob);
        vm.pauseGasMetering();

        expectedSupplyShares -= expectedWithdrawnShares;
        assertEq(returnAssets, amountWithdrawn, "returned asset amount");

        (uint256 lendShares,,) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq(lendShares, expectedSupplyShares, "lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendShares, expectedSupplyShares, "total lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendAssets, pos.lent - amountWithdrawn, "total supply");
        assertEq($.loanToken.balanceOf($.bob), amountWithdrawn, "receiver balance");
        assertEq($.loanToken.balanceOf($.carol), pos.borrowed, "borrower balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), pos.lent - pos.borrowed - amountWithdrawn, "Dahlia balance");
    }

    function test_int_withdraw_onBehalfOfByShares(TestTypes.MarketPosition memory pos, uint256 sharesWithdrawn)
        public
    {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);
        vm.dahliaSubmitPosition(pos, $.alice, $.carol, $);

        uint256 expectedSupplyShares = pos.lent.toSharesDown(0, 0);
        uint256 availableLiquidity = pos.lent - pos.borrowed;
        uint256 withdrawableShares = availableLiquidity.toSharesDown(pos.lent, expectedSupplyShares);
        vm.assume(withdrawableShares != 0);

        sharesWithdrawn = bound(sharesWithdrawn, 1, withdrawableShares);
        uint256 expectedAmountWithdrawn = sharesWithdrawn.toAssetsDown(pos.lent, expectedSupplyShares);

        // SET authorization for manager
        address ALICE_MONEY_MANAGER = makeAddr("ALICE_MONEY_MANAGER");

        vm.prank($.alice);
        $.dahlia.updatePermission(ALICE_MONEY_MANAGER, true);
        vm.prank(ALICE_MONEY_MANAGER);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.Withdraw($.marketId, ALICE_MONEY_MANAGER, $.alice, $.bob, expectedAmountWithdrawn, sharesWithdrawn);
        vm.resumeGasMetering();
        uint256 returnAssets = $.dahlia.withdraw($.marketId, sharesWithdrawn, $.alice, $.bob);
        vm.pauseGasMetering();

        expectedSupplyShares -= sharesWithdrawn;
        assertEq(returnAssets, expectedAmountWithdrawn, "returned asset amount");
        (uint256 lendShares,,) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq(lendShares, expectedSupplyShares, "lend shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendAssets, pos.lent - expectedAmountWithdrawn, "total supply");
        assertEq($.dahlia.getMarket($.marketId).totalLendShares, expectedSupplyShares, "total lend shares");
        assertEq($.loanToken.balanceOf($.bob), expectedAmountWithdrawn, "receiver balance");
        assertEq(
            $.loanToken.balanceOf(address($.dahlia)),
            pos.lent - pos.borrowed - expectedAmountWithdrawn,
            "Dahlia balance"
        );
    }
}
