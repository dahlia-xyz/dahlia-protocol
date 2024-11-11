// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestContext} from "test/common/TestContext.sol";

contract MarketStatusIntegrationTest is Test {
    using SharesMathLib for uint256;
    using FixedPointMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", MarketMath.toPercent(80));
    }

    function test_updateMarketBonusRates_by_attacker(address attacker) public {
        vm.pauseGasMetering();
        vm.assume(attacker != $.owner);
        vm.assume(attacker != $.marketAdmin);
        vm.prank(attacker);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, attacker));
        $.dahlia.updateMarketBonusRates($.marketId, 1, 0);
    }

    function test_updateMarketBonusRates_by_owner(uint256 liquidationBonusRate, uint256 reallocationBonusRate) public {
        vm.pauseGasMetering();
        uint256 rltv = $.dahlia.getMarket($.marketId).rltv;
        liquidationBonusRate = bound(
            liquidationBonusRate,
            Constants.DEFAULT_MIN_LIQUIDATION_BONUS_RATE,
            Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE
        );
        uint256 upper = (liquidationBonusRate - 1).min(MarketMath.calcReallocationBonusRate(rltv));
        reallocationBonusRate = bound(reallocationBonusRate, 0, upper);
        for (uint256 i = 0; i < $.permitted.length; i++) {
            address permitted = $.permitted[i];
            vm.prank(permitted);
            vm.expectEmit(true, true, true, true, address($.dahlia));
            emit Events.MarketBonusRatesChanged(liquidationBonusRate, reallocationBonusRate);
            vm.resumeGasMetering();
            $.dahlia.updateMarketBonusRates($.marketId, liquidationBonusRate, reallocationBonusRate);
            vm.pauseGasMetering();
            IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
            assertEq(market.liquidationBonusRate, liquidationBonusRate);
            assertEq(market.reallocationBonusRate, reallocationBonusRate);
        }
    }
}
