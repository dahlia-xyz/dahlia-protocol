// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TestContext } from "./common/TestContext.sol";
import { DahliaTest } from "./common/abstracts/DahliaTest.sol";
import { console } from "@forge-std/Test.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { IDahlia } from "src/core/contracts/Dahlia.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

abstract contract POSTest is DahliaTest {
    using LibString for *;

    TestContext.MarketContext $;
    TestContext ctx;

    constructor() { }
    // Verifies that no interest accrual has occurred when market conditions remain static.

    function _checkInterestDidntChange() internal {
        vm.pauseGasMetering();
        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);

        uint256 totalBorrowBeforeAccrued = state.totalBorrowAssets;
        uint256 totalLendBeforeAccrued = state.totalLendAssets;
        uint256 totalLendSharesBeforeAccrued = state.totalLendShares;

        // Fetch updated market state to validate
        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.owner);
        IDahlia.Market memory stateAfter = $.dahlia.getMarket($.marketId);

        assertEq(stateAfter.totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow unchanged");
        assertEq(stateAfter.totalLendAssets, totalLendBeforeAccrued, "total supply unchanged");
        assertEq(stateAfter.totalLendShares, totalLendSharesBeforeAccrued, "total supply shares unchanged");
        assertEq(userPos.lendShares, 0, "feeRecipient's supply shares");
    }

    // Prints the state of the lending market for debugging and analysis.
    function printMarketState(string memory suffix, string memory title) public view {
        console.log("\n#### BLOCK:", block.number, title);
        IDahlia.Market memory state = $.dahlia.getMarket($.marketId);

        console.log(suffix, "market.totalLendAssets", state.totalLendAssets);
        console.log(suffix, "market.totalLendShares", state.totalLendShares);
        console.log(suffix, "market.totalBorrowShares", state.totalBorrowShares);
        console.log(suffix, "market.totalBorrowAssets", state.totalBorrowAssets);
        console.log(suffix, "market.totalPrincipal", state.totalLendPrincipalAssets);
        console.log(suffix, "market.utilization", state.totalBorrowAssets * 100_000 / state.totalLendAssets);
        console.log(suffix, "market.ratePerSec", state.ratePerSec);
        console.log(suffix, "market.borrowAPY", percentPerSecToAPY(state.ratePerSec));
        WrappedVault vault = WrappedVault(address(state.vault));
        (,, uint96 rate) = vault.rewardToInterval(state.loanToken);
        console.log(suffix, "market.rewardAPY", percentPerSecToAPY(rate));
        // 100%
        //console.log(suffix, "market.lendAPY", (state.totalBorrowAssets * state.ratePerSec * 365.24 days * 1000 / 1e18) / state.totalLendAssets);
        console.log(suffix, "dahlia.usdc.balance", $.loanToken.balanceOf(address($.dahlia)));

        // Display positions for key actors in the market
        printUserPos(string.concat(suffix, " carol"), $.carol);
        printUserPos(string.concat(suffix, " bob"), $.bob);
        printUserPos(string.concat(suffix, " protocolFee"), $.protocolFeeRecipient);
    }

    // Prints a user's position in the lending market.
    function printUserPos(string memory suffix, address user) public view {
        IDahlia.UserPosition memory pos = $.dahlia.getPosition($.marketId, user);

        console.log(suffix, ".WrappedVault.balanceOf", WrappedVault(address($.dahlia.getMarket($.marketId).vault)).balanceOf(user));
        console.log(suffix, ".WrappedVault.principal", WrappedVault(address($.dahlia.getMarket($.marketId).vault)).principal(user));
        console.log(suffix, ".lendAssets", pos.lendPrincipalAssets);
        console.log(suffix, ".lendShares", pos.lendShares);
        console.log(suffix, ".usdc.balance", $.loanToken.balanceOf(user));
    }

    // Validates a user's position, including interest and shares, against expected values.
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
}
