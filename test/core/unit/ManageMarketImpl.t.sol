// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {ManageMarketImpl} from "src/core/impl/ManageMarketImpl.sol";
import {Types} from "src/core/types/Types.sol";
import {TestContext} from "test/common/TestContext.sol";

contract ManageMarketImplUnitTest is Test {
    TestContext ctx;
    mapping(Types.MarketId => Types.MarketData) internal markets;

    function setUp() public {
        ctx = new TestContext(vm);
    }

    function test_unit_manage_deployMarket_success(Types.MarketConfig memory marketParamsFuzz) public {
        marketParamsFuzz.irm = ctx.createTestIrm();
        marketParamsFuzz.lltv =
            bound(marketParamsFuzz.lltv, Constants.DEFAULT_MIN_LLTV_RANGE, Constants.DEFAULT_MAX_LLTV_RANGE);

        Types.MarketId marketParamsFuzzId = Types.MarketId.wrap(1);
        vm.expectEmit(true, true, true, true, address(this));
        emit Events.DeployMarket(marketParamsFuzzId, marketParamsFuzz);
        ManageMarketImpl.deployMarket(markets, marketParamsFuzzId, marketParamsFuzz);

        Types.Market memory market = markets[marketParamsFuzzId].market;
        assertEq(market.collateralToken, marketParamsFuzz.collateralToken);
        assertEq(market.loanToken, marketParamsFuzz.loanToken);
        assertEq(address(market.irm), address(marketParamsFuzz.irm));
        assertEq(market.oracle, marketParamsFuzz.oracle);
        assertEq(market.lltv, marketParamsFuzz.lltv);

        assertEq(market.updatedAt, block.timestamp, "updatedAt != block.timestamp");
        assertEq(market.totalLendAssets, 0, "totalLendAssets != 0");
        assertEq(market.totalLendShares, 0, "totalLendShares != 0");
        assertEq(market.totalBorrowAssets, 0, "totalBorrowAssets != 0");
        assertEq(market.totalBorrowShares, 0, "totalBorrowShares != 0");
        assertEq(market.protocolFeeRate, 0, "fee != 0");
    }

    function test_unit_manage_deployMarket_alreadyDeployed(Types.MarketConfig memory marketParamsFuzz) public {
        marketParamsFuzz.irm = ctx.createTestIrm();
        marketParamsFuzz.lltv =
            bound(marketParamsFuzz.lltv, Constants.DEFAULT_MIN_LLTV_RANGE, Constants.DEFAULT_MAX_LLTV_RANGE);
        Types.MarketId marketParamsFuzzId = Types.MarketId.wrap(1);

        ManageMarketImpl.deployMarket(markets, marketParamsFuzzId, marketParamsFuzz);

        vm.expectRevert(Errors.MarketAlreadyDeployed.selector);
        ManageMarketImpl.deployMarket(markets, marketParamsFuzzId, marketParamsFuzz);
    }
}
