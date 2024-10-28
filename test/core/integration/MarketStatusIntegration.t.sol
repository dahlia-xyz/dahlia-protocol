// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";
import {ERC20Mock} from "test/common/mocks/ERC20Mock.sol";

contract MarketStatusIntegrationTest is Test {
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_marketStatus_pause() public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.pauseMarket($.marketId);

        // pause
        vm.prank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.MarketStatusChanged(Types.MarketStatus.Active, Types.MarketStatus.Paused);
        $.dahlia.pauseMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(Types.MarketStatus.Paused));

        // check is forbidden to lend, borrow, supply
        validate_checkIsForbiddenToSupplyLendBorrow(abi.encodeWithSelector(Errors.MarketPaused.selector));

        // revert when pause not active market
        vm.prank($.owner);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.pauseMarket($.marketId);
    }

    function test_int_marketStatus_unpause() public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.unpauseMarket($.marketId);

        // revert when unpause active market
        vm.prank($.owner);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.unpauseMarket($.marketId);

        // pause
        vm.prank($.owner);
        $.dahlia.pauseMarket($.marketId);

        // unpause
        vm.startPrank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.MarketStatusChanged(Types.MarketStatus.Paused, Types.MarketStatus.Active);
        $.dahlia.unpauseMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(Types.MarketStatus.Active));
        vm.stopPrank();
    }

    function test_int_marketStatus_deprecate() public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.deprecateMarket($.marketId);

        // deprecate
        vm.startPrank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.MarketStatusChanged(Types.MarketStatus.Active, Types.MarketStatus.Deprecated);
        $.dahlia.deprecateMarket($.marketId);
        assertEq(uint256($.dahlia.getMarket($.marketId).status), uint256(Types.MarketStatus.Deprecated));
        vm.stopPrank();

        validate_checkIsForbiddenToSupplyLendBorrow(abi.encodeWithSelector(Errors.MarketDeprecated.selector));

        // check unpause revertion
        vm.prank($.owner);
        vm.expectRevert(Errors.CannotChangeMarketStatus.selector);
        $.dahlia.unpauseMarket($.marketId);
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
        IERC20($.marketConfig.loanToken).approve(address($.dahlia), assets);
        vm.expectRevert(revertData);
        $.dahlia.lend($.marketId, assets, $.alice, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();

        // check BorrowImpl
        vm.prank($.alice);
        vm.expectRevert(revertData);
        $.dahlia.borrow($.marketId, assets, 0, $.alice, $.alice);
        vm.resumeGasMetering();
    }
}
