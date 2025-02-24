// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from "@forge-std/console.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

// Test for tracking and validating market interest accruals, lender/borrower positions,
// and fee distribution in Dahlia Protocol.
contract POSTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;
    using LibString for uint256;

    TestContext.MarketContext $;
    TestContext ctx;

    // Sets up the test environment by creating a lending market with 80% Liquidation Loan-to-Value.
    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", BoundUtils.toPercent(80));
    }

    function printPos(string memory suffix) public view {
        console.log(suffix, "vault.principal(address(0)", $.vault.principal(address(0)));
        console.log(suffix, "vault.totalPrincipal()", $.vault.totalPrincipal());
        console.log(suffix, "vault.balanceOf(address(0))", $.vault.balanceOf(address(0)));
        console.log(suffix, "vault.balanceOf(carol)", $.vault.balanceOf($.carol));
        console.log(suffix, "vault.balanceOf(address(this))", $.vault.balanceOf(address(this)));
        console.log(suffix, "token.balanceOf(vault)", $.loanToken.balanceOf(address($.vault)));
        console.log(suffix, "token.balanceOf(address(0))", $.loanToken.balanceOf(address(0)));
        console.log(suffix, "token.balanceOf(carol)", $.loanToken.balanceOf($.carol));
        console.log(suffix, "token.balanceOf(address(this))", $.loanToken.balanceOf(address(this)));
        console.log(suffix, "vault.currentUserRewards(address(0))", $.vault.currentUserRewards(address($.loanToken), address(0)));
        console.log(suffix, "vault.currentUserRewards(carol)", $.vault.currentUserRewards(address($.loanToken), $.carol));
        console.log("");
    }

    // This is manual test to show how owner of the market can claim undistributed rewards
    // run side by side 2 tests to see how reward token will be distributed
    // `forge test -vv --mt test_claimByOwner_oneLenderInTheMiddle` - single lender
    // `forge test -vv --mt test_claimByOwner_noLending` - no lenders
    //
    function test_claimByOwner_noLending() public {
        vm.pauseGasMetering();

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        WrappedVault vault = WrappedVault(address(market.vault));
        assertEq(vault.totalPrincipal(), Constants.BURN_ASSET, "totalPrincipal initial");
        vm.prank(vault.owner());
        vault.addRewardsToken(address($.loanToken));

        vm.startPrank($.marketAdmin);

        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;
        uint256 rewardAmount1 = 1000 * 10 ** $.loanToken.decimals(); // 1000 rewards1
        //        ERC20Mock($.loanToken).setBalance(address(this), rewardAmount1);
        $.loanToken.mint($.marketAdmin, rewardAmount1);
        $.loanToken.approve(address($.vault), rewardAmount1);
        vm.stopPrank();

        printPos("0");
        vm.prank(vault.owner());
        $.vault.setRewardsInterval(address($.loanToken), start + 1, start + duration, rewardAmount1, $.protocolFeeRecipient);
        printPos("1 rewards added");

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        skip(duration / 2);

        printPos("2 after half of period and before owner claim");
        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        printPos("2 after half of period and after owner claim");
        skip(duration);
        printPos("3 after full period");
        $.vault.claim($.carol);

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        printPos("4 after owner claim");
        assertEq(vault.totalPrincipal(), Constants.BURN_ASSET, "totalPrincipal final");

        skip(duration);
        $.vault.claim($.carol);

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        printPos("5 out of period after owner claim");
        assertEq(vault.totalPrincipal(), Constants.BURN_ASSET, "totalPrincipal final");
    }

    function test_claimByOwner_oneLenderInTheMiddle() public {
        vm.pauseGasMetering();

        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        WrappedVault vault = WrappedVault(address(market.vault));
        assertEq(vault.totalPrincipal(), Constants.BURN_ASSET, "totalPrincipal initial");
        vm.prank(vault.owner());
        vault.addRewardsToken(address($.loanToken));

        vm.startPrank($.marketAdmin);

        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;
        uint256 rewardAmount1 = 1000 * 10 ** $.loanToken.decimals(); // 1000 rewards1
        $.loanToken.mint($.marketAdmin, rewardAmount1);
        $.loanToken.approve(address($.vault), rewardAmount1);
        vm.stopPrank();

        printPos("0");
        vm.prank(vault.owner());
        $.vault.setRewardsInterval(address($.loanToken), start + 1, start + duration, rewardAmount1, $.protocolFeeRecipient);
        printPos("1 rewards added");

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));
        printPos("1 owner claim do nothing");

        vm.warp(start + (duration / 2));

        printPos("2 after half of period and before owner claim");

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        /// MOVE THIS LINE
        vm.dahliaLendBy($.carol, rewardAmount1, $);
        /// MOVE THIS LINE

        printPos("2 after half of period and after owner claim");

        skip(10_000); // skip 10000 blocks in the middle of rewards
        console.log("carol currentUserRewards(): ", $.vault.currentUserRewards($.carol, address($.loanToken)));
        printPos("2.1 after 10000 blocks");

        /// MOVE THIS LINE
        vm.dahliaWithdrawBy($.carol, $.vault.balanceOf($.carol), $);
        /// MOVE THIS LINE

        vm.prank($.carol);
        $.vault.claim($.carol);

        printPos("2.1 after 10000 blocks and claim");

        vm.warp(start + duration); // end of rewards period
        printPos("3 after full period");

        vm.prank($.carol);
        $.vault.claim($.carol);

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        printPos("4 after owner claim");

        skip(10_000); // skip more to see if we can still claim

        vm.prank($.carol);
        $.vault.claim($.carol);

        vm.prank(vault.owner());
        $.vault.ownerClaim(address(this), address($.loanToken));

        vm.prank($.carol);
        $.vault.claim($.carol);

        printPos("5 out of period after owner claim");
        console.log("carol currentUserRewards(): ", $.vault.currentUserRewards($.carol, address($.loanToken)));
    }
}
