// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {WrappedVault} from "@royco/WrappedVault.sol";

import {console} from "forge-std/console.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {RoycoMock} from "test/common/mocks/RoycoMock.sol";

contract RoycoIntegrationTest is Test {
    using BoundUtils for Vm;

    IERC4626 marketProxy;

    TestContext.MarketContext $;
    RoycoMock.RoycoContracts royco;
    TestContext ctx;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
        royco = ctx.createRoycoContracts();
        marketProxy = IERC4626($.dahlia.getMarket($.marketId).marketProxy);
    }

    function test_int_royco_manuallyWrapVault() public {
        uint256 rewardAmount = 1000e6;
        ctx.mint("USDC", "OWNER", 2 * rewardAmount);

        WrappedVault wrappedVault = royco.erc4626iFactory.wrapVault(marketProxy, $.owner, "Test vault", 0.02e18);
        assertTrue(royco.erc4626iFactory.isVault(address(wrappedVault)));
        vm.startPrank($.owner);
        wrappedVault.addRewardsToken(address($.loanToken));
        $.loanToken.approve(address(wrappedVault), rewardAmount);
        wrappedVault.setRewardsInterval(
            address($.loanToken),
            uint32(block.timestamp) - 6 days,
            uint32(block.timestamp + 1 days),
            rewardAmount,
            address($.dahlia)
        );
        (,, uint96 rate1) = wrappedVault.rewardToInterval(address($.loanToken));
        console.log("rate1", uint256(rate1));
        $.loanToken.approve(address(wrappedVault), rewardAmount);
        vm.warp(block.timestamp + 1 days + 1);
        wrappedVault.setRewardsInterval(
            address($.loanToken), uint32(block.timestamp), uint32(block.timestamp + 7 days), 1e6, address($.dahlia)
        );
        (,, uint96 rate2) = wrappedVault.rewardToInterval(address($.loanToken));
        console.log("rate2", uint256(rate2));
        //        wrappedVault.extendRewardsInterval(address($.loanToken), 1, uint32(block.timestamp) + 8 days, address($.dahlia));
        vm.stopPrank();
    }

    function test_int_royco_autoWrapVault() public {
        Types.MarketConfig memory marketConfig =
            ctx.createMarketConfig("USDC", "WBTC", MarketMath.toPercent(70), MarketMath.toPercent(80));
        Types.MarketId marketId = ctx.deployDahliaMarket(marketConfig);
        assertEq(Types.MarketId.unwrap(marketId), 2);

        // vm.expectEmit(true, true, true, true, address(royco.erc4626iFactory));
        // DahliaProvider.IncentivizedVaultCreated();
    }
}
