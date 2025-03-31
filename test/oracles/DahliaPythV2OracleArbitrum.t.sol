// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { DahliaPythV2Oracle } from "src/oracles/contracts/DahliaPythV2Oracle.sol";
import { DahliaPythV2OracleFactory } from "src/oracles/contracts/DahliaPythV2OracleFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Arbitrum } from "test/oracles/Constants.sol";

contract DahliaPythV2OracleArbitrumTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    DahliaPythV2OracleFactory factory;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        ctx = new TestContext(vm);
        factory = ctx.createPythV2OracleFactory(Arbitrum.PYTH_STATIC_ORACLE_ADDRESS);
    }

    function test_oracle_RoycoTest_USDC_success() public {
        DahliaPythV2Oracle oracle;
        DahliaPythV2Oracle.Delays memory delays;
        delays = DahliaPythV2Oracle.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 0, quoteMaxDelaySecondary: 0 });
        oracle = DahliaPythV2Oracle(
            factory.createPythV2Oracle(
                DahliaPythV2Oracle.Params({
                    baseToken: Arbitrum.ERC20_ROYCO_TEST,
                    baseFeedPrimary: bytes32(0),
                    baseFeedSecondary: bytes32(0),
                    quoteToken: Arbitrum.ERC20_USDC,
                    quoteFeedPrimary: bytes32(0),
                    quoteFeedSecondary: bytes32(0)
                }),
                delays
            )
        );

        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1e36, "price");
        assertEq(_isBadData, false);
        uint256 one = 10 ** IERC20Metadata(Arbitrum.ERC20_ROYCO_TEST).decimals();
        uint256 result = MarketMath.calcMaxBorrowAssets(_price, one, Constants.LLTV_100_PERCENT);
        assertEq(result, 1_000_000, "conversion");
        assertEq(one, 1_000_000, "one");
    }

    function test_oracle_RoycoTest_WETH_success() public {
        DahliaPythV2Oracle oracle;
        DahliaPythV2Oracle.Delays memory delays;
        delays = DahliaPythV2Oracle.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 0, quoteMaxDelaySecondary: 0 });
        oracle = DahliaPythV2Oracle(
            factory.createPythV2Oracle(
                DahliaPythV2Oracle.Params({
                    baseToken: Arbitrum.ERC20_ROYCO_TEST,
                    baseFeedPrimary: bytes32(0),
                    baseFeedSecondary: bytes32(0),
                    quoteToken: Arbitrum.ERC20_WETH,
                    quoteFeedPrimary: bytes32(0),
                    quoteFeedSecondary: bytes32(0)
                }),
                delays
            )
        );

        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1e48, "price");
        assertEq(_isBadData, false);
        uint256 one = 10 ** IERC20Metadata(Arbitrum.ERC20_ROYCO_TEST).decimals();
        uint256 result = MarketMath.calcMaxBorrowAssets(_price, one, Constants.LLTV_100_PERCENT);
        assertEq(result, 1e18, "conversion"); // weth 18 decimals
        assertEq(one, 1e6, "one"); // royco has 6 decimals
    }
}
