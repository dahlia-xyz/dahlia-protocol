// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { IERC20 } from "@forge-std/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants, TestContext } from "test/common/TestContext.sol";
import { ERC20Mock } from "test/common/mocks/ERC20Mock.sol";

contract MarketStatusIntegrationTest is Test {
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext internal $;
    TestContext internal ctx;
    address internal permitted;

    modifier usePermittedOwners() {
        for (uint256 i = 0; i < $.permitted.length; i++) {
            permitted = $.permitted[i];
            _;
            vm.clearMockedCalls();
        }
    }

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_marketStatus_pause() public usePermittedOwners {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, address(this)));
        $.dahlia.pauseMarket($.marketId);

        // pause
        vm.prank(permitted);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Active, IDahlia.MarketStatus.Pause);
        $.dahlia.pauseMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(IDahlia.MarketStatus.Pause));

        // check is forbidden to lend, borrow, supply
        validate_checkIsForbiddenToSupplyLendBorrow(abi.encodeWithSelector(Errors.MarketPaused.selector));

        // revert when pause not active market
        vm.prank(permitted);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.pauseMarket($.marketId);
        // unpause
        vm.prank(permitted);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Pause, IDahlia.MarketStatus.Active);
        $.dahlia.unpauseMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(IDahlia.MarketStatus.Active));
    }

    function test_int_marketStatus_unpause() public usePermittedOwners {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPermitted.selector, address(this)));
        $.dahlia.unpauseMarket($.marketId);

        // revert when unpause active market
        vm.prank(permitted);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.unpauseMarket($.marketId);

        // pause
        vm.prank(permitted);
        $.dahlia.pauseMarket($.marketId);

        // unpause
        vm.startPrank(permitted);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Pause, IDahlia.MarketStatus.Active);
        $.dahlia.unpauseMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(IDahlia.MarketStatus.Active));
        vm.stopPrank();
    }

    function test_int_marketStatus_deprecate() public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.deprecateMarket($.marketId);

        // deprecate
        vm.startPrank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.MarketStatusChanged($.marketId, IDahlia.MarketStatus.Active, IDahlia.MarketStatus.Deprecate);
        $.dahlia.deprecateMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(IDahlia.MarketStatus.Deprecate));
        vm.stopPrank();

        validate_checkIsForbiddenToSupplyLendBorrow(abi.encodeWithSelector(Errors.MarketDeprecated.selector));

        // check unpause reversion
        vm.prank($.owner);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.unpauseMarket($.marketId);

        // check cannot deprecate twice
        vm.prank($.owner);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.deprecateMarket($.marketId);
    }

    function validate_checkIsForbiddenToSupplyLendBorrow(bytes memory revertData) internal {
        vm.pauseGasMetering();
        // check supply
        uint256 assets = 100;
        ERC20Mock($.marketConfig.collateralToken).setBalance($.alice, assets);
        vm.startPrank($.alice);
        IERC20($.marketConfig.collateralToken).approve(address($.dahlia), assets);
        vm.expectRevert(revertData);
        $.dahlia.supplyCollateral($.marketId, assets, $.alice, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();

        // check lend
        ERC20Mock($.marketConfig.loanToken).setBalance($.alice, assets);
        vm.startPrank($.alice);
        IDahlia.Market memory market = $.dahlia.getMarket($.marketId);
        IERC20($.marketConfig.loanToken).approve(address(market.vault), assets);
        vm.expectRevert(revertData);
        market.vault.deposit(assets, $.alice);
        vm.stopPrank();

        // check BorrowImpl
        vm.prank($.alice);
        vm.expectRevert(revertData);
        $.dahlia.borrow($.marketId, assets, $.alice, $.alice);
        vm.resumeGasMetering();
    }
}
