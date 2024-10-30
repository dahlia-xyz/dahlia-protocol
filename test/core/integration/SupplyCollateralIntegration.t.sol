// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants} from "test/common/TestConstants.sol";
import {TestContext} from "test/common/TestContext.sol";
import {ERC20Mock} from "test/common/mocks/ERC20Mock.sol";

contract SupplyCollateralIntegrationTest is Test {
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;

    function setUp() public {
        $ = (new TestContext(vm)).bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_supplyCollateral_marketNotDeployed(Types.MarketId marketIdFuzz, uint256 assets) public {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.assume(assets > 0);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.supplyCollateral(marketIdFuzz, assets, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_supplyCollateral_zeros(uint256 assets) public {
        // check zero address
        assets = vm.boundAmount(assets);
        vm.expectRevert(Errors.ZeroAddress.selector);
        $.dahlia.supplyCollateral($.marketId, assets, address(0), TestConstants.EMPTY_CALLBACK);

        // check zero assets
        vm.expectRevert(Errors.ZeroAssets.selector);
        $.dahlia.supplyCollateral($.marketId, 0, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_supplyCollateral_tokenIsIncorrect(uint256 assets, address token) public {
        assets = vm.boundAmount(assets);

        vm.assume(token.code.length == 0);
        $.marketConfig.collateralToken = token;
        vm.expectRevert(); // internal revert: ERC20: subtraction underflow
        $.dahlia.deployMarket($.marketConfig, TestConstants.EMPTY_CALLBACK);

        vm.expectRevert(); // internal revert: ERC20: subtraction underflow
        $.dahlia.supplyCollateral($.marketId, assets, $.alice, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_supplyCollateral_success(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);

        ERC20Mock($.marketConfig.collateralToken).setBalance($.alice, assets);
        vm.startPrank($.alice);
        IERC20($.marketConfig.collateralToken).approve(address($.dahlia), assets);

        vm.resumeGasMetering();
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SupplyCollateral($.marketId, $.alice, $.alice, assets);
        $.dahlia.supplyCollateral($.marketId, assets, $.alice, TestConstants.EMPTY_CALLBACK);
        vm.pauseGasMetering();
        vm.stopPrank();

        (,, uint256 collateral) = $.dahlia.marketUserPositions($.marketId, $.alice);
        assertEq($.collateralToken.balanceOf($.alice), 0);
        assertEq($.collateralToken.balanceOf(address($.dahlia)), assets);
        assertEq(collateral, assets);
    }
}
