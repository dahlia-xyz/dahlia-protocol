// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Test, Vm } from "@forge-std/Test.sol";
import { DahliaChainlinkOracle } from "src/oracles/contracts/DahliaChainlinkOracle.sol";
import { DahliaDualOracle } from "src/oracles/contracts/DahliaDualOracle.sol";
import { DahliaDualOracleFactory } from "src/oracles/contracts/DahliaDualOracleFactory.sol";
import { DahliaUniswapV3Oracle } from "src/oracles/contracts/DahliaUniswapV3Oracle.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Mainnet } from "test/oracles/Constants.sol";

contract DahliaDualOracleFactoryTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    DahliaDualOracleFactory oracleFactory;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        oracleFactory = ctx.createDualOracleFactory();
    }

    function test_oracleFactory_dual_wethUsdc() public {
        DahliaChainlinkOracle primary = ctx.createChainlinkOracleFactory().createChainlinkOracle(
            DahliaChainlinkOracle.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.ETH_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            DahliaChainlinkOracle.Delays({ baseMaxDelayPrimary: 86_400, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 })
        );

        DahliaUniswapV3Oracle secondary = ctx.createUniswapOracleFactory().createUniswapOracle(
            DahliaUniswapV3Oracle.Params({ baseToken: Mainnet.WETH_ERC20, quoteToken: Mainnet.USDC_ERC20, uniswapV3PairAddress: Mainnet.WETH_USDC_UNI_V3_POOL }),
            900
        );

        DahliaDualOracle oracle = oracleFactory.createDualOracle(primary, secondary);
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2_404_319_134_993_499_349_934_993_499);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2404); // 2404 USDC per 1 WETH
        assertEq(isBadData, false);

        DahliaDualOracle oracle2 = oracleFactory.createDualOracle(primary, secondary);
        assertEq(address(oracle), address(oracle2), "should be the same address");
    }

    function test_oracleFactory_dual_wethUniFromChainlink() public {
        IDahliaOracle primary = ctx.createChainlinkOracleFactory().createChainlinkOracle(
            DahliaChainlinkOracle.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            DahliaChainlinkOracle.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 })
        );

        IDahliaOracle secondary = ctx.createUniswapOracleFactory().createUniswapOracle(
            DahliaUniswapV3Oracle.Params({ baseToken: Mainnet.WETH_ERC20, quoteToken: Mainnet.UNI_ERC20, uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL }),
            900
        );

        DahliaDualOracle oracle = oracleFactory.createDualOracle(primary, secondary);

        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 338_921_318_918_776_963_008_316_417_223_772_858_717);
        assertEq(((price * 1e18) / 1e18) / 1e36, 338); // 338 UNI per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUniWithBadDataFromUni() public {
        IDahliaOracle primary = ctx.createChainlinkOracleFactory().createChainlinkOracle(
            DahliaChainlinkOracle.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            DahliaChainlinkOracle.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 10, quoteMaxDelaySecondary: 0 })
        );

        IDahliaOracle secondary = ctx.createUniswapOracleFactory().createUniswapOracle(
            DahliaUniswapV3Oracle.Params({ baseToken: Mainnet.WETH_ERC20, quoteToken: Mainnet.UNI_ERC20, uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL }),
            900
        );

        DahliaDualOracle oracle = oracleFactory.createDualOracle(primary, secondary);

        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 342_170_188_147_668_813_010_937_084_335_830_514_402);
        assertEq(((price * 1e18) / 1e18) / 1e36, 342); // 342 UNI per 1 WETH
        assertEq(isBadData, false);
    }
}
