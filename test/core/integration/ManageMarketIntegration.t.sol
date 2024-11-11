// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {IDahlia, IMarketStorage} from "src/core/interfaces/IDahlia.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestConstants, TestContext} from "test/common/TestContext.sol";

contract ManageMarketIntegrationTest is Test {
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
    }

    function test_int_manage_isMarketDeployed(IDahlia.MarketId marketId) public view {
        vm.assume(IMarketStorage.MarketId.unwrap(marketId) != IMarketStorage.MarketId.unwrap($.marketId));
        assertEq($.dahlia.isMarketDeployed(marketId), false);
        assertEq($.dahlia.isMarketDeployed($.marketId), true);
    }

    function test_int_manage_setLltvRange(uint24 minLltvFuzz, uint24 maxLltvFuzz) public {
        minLltvFuzz = uint24(bound(minLltvFuzz, 1, Constants.LLTV_100_PERCENT - 1));
        maxLltvFuzz = uint24(bound(maxLltvFuzz, minLltvFuzz, Constants.LLTV_100_PERCENT - 1));

        // firstly check onlyOwner protection
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minLltvFuzz, maxLltvFuzz));

        vm.startPrank($.owner);
        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, 1e6, maxLltvFuzz));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(uint24(1e6), maxLltvFuzz));

        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, minLltvFuzz, 1e6));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minLltvFuzz, uint24(1e6)));

        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, minLltvFuzz, Constants.LLTV_100_PERCENT));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minLltvFuzz, uint24(Constants.LLTV_100_PERCENT)));

        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, 0, maxLltvFuzz));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(0, maxLltvFuzz));

        // check success
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetLLTVRange(minLltvFuzz, maxLltvFuzz);
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minLltvFuzz, maxLltvFuzz));

        (uint24 newMin, uint24 newMax) = $.dahlia.lltvRange();
        assertEq(newMin, minLltvFuzz);
        assertEq(newMax, maxLltvFuzz);
        vm.stopPrank();
    }

    function test_int_manage_setLiquidationBonusRateRange(uint24 minFuzz, uint24 maxFuzz) public {
        maxFuzz = uint24(bound(maxFuzz, 1, Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE));
        minFuzz = uint24(bound(minFuzz, 1, maxFuzz));

        // firstly check onlyOwner protection
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minFuzz, maxFuzz));

        vm.startPrank($.owner);
        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, 1e6, maxFuzz));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(uint24(1e6), maxFuzz));

        // check is range valid
        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, minFuzz, 1e6));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minFuzz, uint24(1e6)));

        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, minFuzz, Constants.LLTV_100_PERCENT));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(minFuzz, uint24(Constants.LLTV_100_PERCENT)));

        vm.expectRevert(abi.encodeWithSelector(Errors.RangeNotValid.selector, 0, maxFuzz));
        $.dahlia.setLltvRange(IMarketStorage.RateRange(0, maxFuzz));

        // check success
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetLiquidationBonusRateRange(minFuzz, maxFuzz);
        $.dahlia.setLiquidationBonusRateRange(IMarketStorage.RateRange(minFuzz, maxFuzz));

        (uint24 newMin, uint24 newMax) = $.dahlia.liquidationBonusRateRange();
        assertEq(newMin, minFuzz);
        assertEq(newMax, maxFuzz);
        vm.stopPrank();
    }

    function test_int_manage_setProtocolFeeRateWhenMarketNotDeployed(
        IMarketStorage.MarketId marketIdFuzz,
        uint32 feeFuzz
    ) public {
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
        feeFuzz = uint32(bound(uint256(feeFuzz), Constants.MAX_FEE_RATE + 1, type(uint32).max));

        vm.prank($.owner);
        vm.expectRevert(Errors.MaxProtocolFeeExceeded.selector);
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        // success
        feeFuzz = uint32(bound(uint256(feeFuzz), 1, Constants.MAX_FEE_RATE));

        vm.prank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetProtocolFeeRate($.marketId, feeFuzz);
        $.dahlia.setProtocolFeeRate($.marketId, feeFuzz);

        assertEq($.dahlia.getMarket($.marketId).protocolFeeRate, feeFuzz);
    }

    function test_int_manage_setReserveFeeRateWhenMarketNotDeployed(IDahlia.MarketId marketIdFuzz, uint32 feeFuzz)
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
        feeFuzz = uint32(bound(uint256(feeFuzz), Constants.MAX_FEE_RATE + 1, type(uint32).max));

        vm.prank($.owner);
        vm.expectRevert(Errors.MaxProtocolFeeExceeded.selector);
        $.dahlia.setReserveFeeRate($.marketId, feeFuzz);

        feeFuzz = uint32(bound(uint256(feeFuzz), 1, Constants.MAX_FEE_RATE));

        // success
        vm.prank($.owner);
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit Events.SetReserveFeeRate($.marketId, feeFuzz);
        $.dahlia.setReserveFeeRate($.marketId, feeFuzz);

        assertEq($.dahlia.getMarket($.marketId).reserveFeeRate, feeFuzz);
    }

    function test_int_manage_deployMarketWhenIrmNotAllowed(IDahlia.MarketConfig memory marketParamsFuzz) public {
        vm.assume(!$.dahliaRegistry.isIrmAllowed(marketParamsFuzz.irm));
        marketParamsFuzz.lltv =
            bound(marketParamsFuzz.lltv, Constants.DEFAULT_MIN_LLTV_RANGE, Constants.DEFAULT_MAX_LLTV_RANGE);

        vm.expectRevert(Errors.IrmNotAllowed.selector);
        $.dahlia.deployMarket(marketParamsFuzz, TestConstants.EMPTY_CALLBACK);
    }

    function test_int_manage_deployMarketWhenLltvNotAllowed(IDahlia.MarketConfig memory marketParamsFuzz) public {
        // need to disable IRM
        marketParamsFuzz.irm = IIrm(address(0));
        marketParamsFuzz.lltv = 0.001e18;

        vm.expectRevert(Errors.LltvNotAllowed.selector);
        $.dahlia.deployMarket(marketParamsFuzz, TestConstants.EMPTY_CALLBACK);
        assertEq($.dahlia.protocolFeeRecipient(), ctx.wallets("PROTOCOL_FEE_RECIPIENT"));
    }

    function test_int_royco_deployWithOwner(address ownerFuzz) public {
        vm.assume(ownerFuzz != address(0));
        IDahlia.MarketConfig memory marketConfig =
            ctx.createMarketConfig("USDC", "WBTC", MarketMath.toPercent(70), MarketMath.toPercent(80));
        marketConfig.owner = ownerFuzz;
        IMarketStorage.MarketId marketId = ctx.deployDahliaMarket(marketConfig);
        assertEq(IMarketStorage.MarketId.unwrap(marketId), 2);
        IDahlia.Market memory market = $.dahlia.getMarket(marketId);
        assertEq(market.vault.vaultOwner(), ownerFuzz);
    }

    function test_int_royco_deployWithNoOwner() public {
        IDahlia.MarketConfig memory marketConfig =
            ctx.createMarketConfig("USDC", "WBTC", MarketMath.toPercent(70), MarketMath.toPercent(80));
        marketConfig.owner = address(0);
        vm.startPrank(ctx.createWallet("OWNER"));
        $.dahlia.dahliaRegistry().allowIrm(marketConfig.irm);
        vm.stopPrank();
        vm.startPrank($.marketAdmin);
        IDahlia.MarketId marketId = $.dahlia.deployMarket(marketConfig, TestConstants.EMPTY_CALLBACK);
        assertEq(IMarketStorage.MarketId.unwrap(marketId), 2);
        IDahlia.Market memory market = $.dahlia.getMarket(marketId);
        assertEq($.dahlia.isMarketDeployed(marketId), true);
        assertEq(market.vault.vaultOwner(), $.marketAdmin);
        vm.stopPrank();
    }
}
