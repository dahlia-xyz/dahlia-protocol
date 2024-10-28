// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWrappedVault} from "@royco/interfaces/IWrappedVault.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {RoycoMock} from "test/common/mocks/RoycoMock.sol";

contract RoycoIntegration is Test {
    using BoundUtils for Vm;

    IERC4626 marketProxy;

    TestContext.MarketContext $;
    RoycoMock.RoycoContracts royco;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
        royco = ctx.createRoycoContracts();
        marketProxy = IERC4626($.dahlia.getMarket($.marketId).marketProxy);
    }

    function test_int_royco_manuallyWrapVault() public {
        IWrappedVault wrappedVault =
            IWrappedVault(royco.erc4626iFactory.wrapVault(marketProxy, $.owner, "Test vault", 1 ether));

        assertTrue(royco.erc4626iFactory.isVault(address(wrappedVault)));
    }

    function test_int_royco_autoWrapVault() public {
        Types.MarketConfig memory marketConfig = ctx.createMarketConfig("USDC", "WBTC", 0.7e5, 0.8e5);
        Types.MarketId marketId = ctx.deployDahliaMarket(marketConfig);
        assertEq(Types.MarketId.unwrap(marketId), 2);

        // vm.expectEmit(true, true, true, true, address(royco.erc4626iFactory));
        // DahliaProvider.IncentivizedVaultCreated();
    }
}
