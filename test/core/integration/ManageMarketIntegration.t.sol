// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {Types} from "src/core/types/Types.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";

contract ManageMarketIntegration is Test {
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_manage_isMarketDeployed(Types.MarketId marketId) public view {
        vm.assume(Types.MarketId.unwrap(marketId) != Types.MarketId.unwrap($.marketId));
        assertEq($.dahlia.isMarketDeployed(marketId), false);
        assertEq($.dahlia.isMarketDeployed($.marketId), true);
    }

    function test_int_manage_setLltvRange(uint256 minLltvFuzz, uint256 maxLltvFuzz) public {
        minLltvFuzz = bound(minLltvFuzz, 1, Constants.LLTV_100_PERCENT - 1);
        maxLltvFuzz = bound(maxLltvFuzz, minLltvFuzz, Constants.LLTV_100_PERCENT - 1);

        // firstly check onlyOwner protection
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setLltvRange(minLltvFuzz, maxLltvFuzz);

        vm.startPrank($.owner);
        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.LltvRangeNotValid.selector, 0.0001e18, maxLltvFuzz));
        $.dahlia.setLltvRange(0.0001e18, maxLltvFuzz);

        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.LltvRangeNotValid.selector, minLltvFuzz, 1e18));
        $.dahlia.setLltvRange(minLltvFuzz, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LltvRangeNotValid.selector, minLltvFuzz, Constants.LLTV_100_PERCENT)
        );
        $.dahlia.setLltvRange(minLltvFuzz, Constants.LLTV_100_PERCENT);

        vm.expectRevert(abi.encodeWithSelector(Errors.LltvRangeNotValid.selector, 0, maxLltvFuzz));
        $.dahlia.setLltvRange(0, maxLltvFuzz);

        // check success
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetLLTVRange(minLltvFuzz, maxLltvFuzz);
        $.dahlia.setLltvRange(minLltvFuzz, maxLltvFuzz);

        assertEq($.dahlia.minLltv(), minLltvFuzz);
        assertEq($.dahlia.maxLltv(), maxLltvFuzz);
        vm.stopPrank();
    }

    function test_int_manage_setProtocolFeeRateWhenMarketNotDeployed(Types.MarketId marketIdFuzz, uint32 feeFuzz)
        public
    {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.prank($.owner);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.setProtocolFeeRate(marketIdFuzz, feeFuzz);
    }

    function test_int_manage_setProtocolFeeRate(uint32 feeFuzz) public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        // revert when too hight
        feeFuzz = uint32(bound(uint256(feeFuzz), Constants.MAX_FEE + 1, type(uint32).max));

        vm.prank($.owner);
        vm.expectRevert(Errors.MaxProtocolFeeExceeded.selector);
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        // success
        feeFuzz = uint32(bound(uint256(feeFuzz), 1, Constants.MAX_FEE));

        vm.prank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetProtocolFeeRate($.marketId, feeFuzz);
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        assertEq($.dahlia.getMarket($.marketId).protocolFeeRate, feeFuzz);
    }

    function test_int_manage_setReserveFeeRateWhenMarketNotDeployed(Types.MarketId marketIdFuzz, uint32 feeFuzz)
        public
    {
        vm.assume(!vm.marketsEq($.marketId, marketIdFuzz));
        vm.prank($.owner);
        vm.expectRevert(Errors.MarketNotDeployed.selector);
        $.dahlia.setReserveFeeRate(marketIdFuzz, feeFuzz);
    }

    function test_int_manage_setProtocolFeeRecipient(address protocolFuzz) public {
        vm.assume(protocolFuzz != address(0) && protocolFuzz != $.dahlia.protocolFeeRecipient());
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setProtocolFeeRecipient(protocolFuzz);

        vm.startPrank($.owner);
        // revert when zero adress
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        $.dahlia.setProtocolFeeRecipient(address(0));

        // success
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetProtocolFeeRecipient(protocolFuzz);
        $.dahlia.setProtocolFeeRecipient(protocolFuzz);
        assertEq($.dahlia.protocolFeeRecipient(), protocolFuzz);

        // revert when already set
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadySet.selector));
        $.dahlia.setProtocolFeeRecipient(protocolFuzz);
    }

    function test_int_manage_setReserveFeeRecipient(address recipientFuzz) public {
        vm.assume(recipientFuzz != address(0) && recipientFuzz != $.dahlia.reserveFeeRecipient());
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setReserveFeeRecipient(recipientFuzz);

        vm.startPrank($.owner);
        // revert when zero adress
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        $.dahlia.setReserveFeeRecipient(address(0));

        // success
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetReserveFeeRecipient(recipientFuzz);
        $.dahlia.setReserveFeeRecipient(recipientFuzz);
        assertEq($.dahlia.reserveFeeRecipient(), recipientFuzz);

        // revert when already set
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadySet.selector));
        $.dahlia.setReserveFeeRecipient(recipientFuzz);
    }

    function test_int_manage_setReserveFeeRate(uint32 feeFuzz) public {
        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        // revert when too hight
        feeFuzz = uint32(bound(uint256(feeFuzz), Constants.MAX_FEE + 1, type(uint32).max));

        vm.prank($.owner);
        vm.expectRevert(Errors.MaxProtocolFeeExceeded.selector);
        $.dahlia.setReserveFeeRate($.marketId, feeFuzz);

        feeFuzz = uint32(bound(uint256(feeFuzz), 1, Constants.MAX_FEE));

        // success
        vm.prank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetReserveFeeRate($.marketId, feeFuzz);
        $.dahlia.setReserveFeeRate($.marketId, feeFuzz);

        assertEq($.dahlia.getMarket($.marketId).reserveFeeRate, feeFuzz);
    }

    function test_int_manage_deployMarketWhenIrmNotAllowed(Types.MarketConfig memory marketParamsFuzz) public {
        vm.assume(!$.dahliaRegistry.isIrmAllowed(marketParamsFuzz.irm));
        marketParamsFuzz.lltv =
            bound(marketParamsFuzz.lltv, Constants.DEFAULT_MIN_LLTV_RANGE, Constants.DEFAULT_MAX_LLTV_RANGE);

        vm.expectRevert(Errors.IrmNotAllowed.selector);
        $.dahlia.deployMarket(marketParamsFuzz, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_manage_deployMarketWhenLltvNotAllowed(Types.MarketConfig memory marketParamsFuzz) public {
        // need to disable IRM
        marketParamsFuzz.irm = IIrm(address(0));
        marketParamsFuzz.lltv = 0.001e18;

        vm.expectRevert(Errors.LltvNotAllowed.selector);
        $.dahlia.deployMarket(marketParamsFuzz, TestConstants.EMPTY_CALLBACK);
        assertEq($.dahlia.protocolFeeRecipient(), ctx.wallets("PROTOCOL_FEE_RECIPIENT"));
    }
}
