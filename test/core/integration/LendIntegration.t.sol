// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";

contract LendIntegrationTest is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;

    function setUp() public {
        $ = (new TestContext(vm)).bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_lend_marketNotDeployed(Types.MarketId marketIdFuzz, uint256 assets) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.lend(marketIdFuzz, assets, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_lend_zeroAmount() public {
        //        vm.expectRevert(Errors.InconsistentAssetsOrSharesInput.selector);
        $.dahlia.lend($.marketId, 0, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_lend_zeroAddress(uint256 assets) public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.lend($.marketId, assets, address(0), TestConstants.EMPTY_CALLBACK);
    }

    function test_int_lend_byAssets(uint256 amount) public {
        vm.pauseGasMetering();
        amount = vm.boundAmount(amount);
        uint256 expectedLendShares = amount.toSharesDown(0, 0);

        $.loanToken.setBalance($.alice, amount);

        vm.startPrank($.alice);
        $.loanToken.approve(address($.dahlia), amount);

        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.Lend($.marketId, $.alice, $.bob, amount, expectedLendShares);
        vm.resumeGasMetering();
        (uint256 _shares) = $.dahlia.lend($.marketId, amount, $.bob, TestConstants.EMPTY_CALLBACK);
        vm.pauseGasMetering();
        vm.stopPrank();

        Types.MarketUserPosition memory userPos = $.dahlia.getMarketUserPosition($.marketId, $.bob);

        assertEq(_shares, expectedLendShares, "returned shares amount");
        assertEq(userPos.lendShares, expectedLendShares, "supply shares");
        assertEq($.dahlia.getMarket($.marketId).totalLendAssets, amount, "total supply");
        assertEq($.dahlia.getMarket($.marketId).totalLendShares, expectedLendShares, "total supply shares");
        assertEq($.loanToken.balanceOf($.alice), 0, "Alice balance");
        assertEq($.loanToken.balanceOf(address($.dahlia)), amount, "Dahlia balance");
    }
}
