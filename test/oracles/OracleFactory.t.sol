// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Test, Vm } from "@forge-std/Test.sol";
import { ChainlinkOracleWithMaxDelayBase } from "src/oracles/abstracts/ChainlinkOracleWithMaxDelayBase.sol";
import { UniswapOracleV3SingleTwapBase } from "src/oracles/abstracts/UniswapOracleV3SingleTwapBase.sol";
import { ChainlinkOracleWithMaxDelay, DahliaOracleFactory, DualOracleChainlinkUniV3 } from "src/oracles/contracts/DahliaOracleFactory.sol";
import { StablePriceOracle } from "src/oracles/contracts/StablePriceOracle.sol";
import { UniswapOracleV3SingleTwap } from "src/oracles/contracts/UniswapOracleV3SingleTwap.sol";
import { IChainlinkOracleWithMaxDelay } from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Mainnet } from "test/oracles/Constants.sol";

contract OracleFactoryTest is Test {
    using BoundUtils for Vm;

    uint256 ORACLE_PRECISION = 1e18;
    TestContext ctx;
    DahliaOracleFactory oracleFactory;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        oracleFactory = DahliaOracleFactory(ctx.createOracleFactory());
    }

    function test_oracleFactory_chainlink() public {
        /// @dev USDC is collateral, WBTC is loan, then result is 0.000016xxx
        ChainlinkOracleWithMaxDelay oracle = oracleFactory.createChainlinkOracle(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.USDC_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.WBTC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.BTC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(Mainnet.WBTC_BTC_CHAINLINK_ORACLE)
            }),
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 86_400
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 1_611_859_162_144_102_979_080_952_870_358_934);
        assertEq(isBadData, false);
    }

    function test_oracleFactory_paxg_chainlink() public {
        /// @dev PAXG is collateral, USDC is loan, then result is 2617
        ChainlinkOracleWithMaxDelay oracle = oracleFactory.createChainlinkOracle(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: 0x45804880De22913dAFE09f4980848ECE6EcbAf78,
                baseFeedPrimary: AggregatorV3Interface(0x7C4561Bb0F2d6947BeDA10F667191f6026E7Ac0c),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 0
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2_617_340_351_185_118_511_851_185_118);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2617); // 2617 USDC per 1 PAXG
        assertEq(isBadData, false);
    }

    function test_oracleFactory_wethUsdc() public {
        ChainlinkOracleWithMaxDelay oracle = oracleFactory.createChainlinkOracle(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.ETH_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 0
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2_404_319_134_993_499_349_934_993_499);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2404); // 2404 USDC per 1 ETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_uniswap_wethUsdc() public {
        UniswapOracleV3SingleTwap oracle = oracleFactory.createUniswapOracle(
            UniswapOracleV3SingleTwapBase.OracleParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.USDC_ERC20,
                uniswapV3PairAddress: Mainnet.WETH_USDC_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2_412_486_481_775_144_671_894_069_994);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2412); // 2412 USDC per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUsdc() public {
        DualOracleChainlinkUniV3 oracle = oracleFactory.createDualOracleChainlinkUniV3(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.ETH_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 0
            }),
            UniswapOracleV3SingleTwapBase.OracleParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.USDC_ERC20,
                uniswapV3PairAddress: Mainnet.WETH_USDC_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2_404_319_134_993_499_349_934_993_499);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2404); // 2404 USDC per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUniFromChainlink() public {
        DualOracleChainlinkUniV3 oracle = oracleFactory.createDualOracleChainlinkUniV3(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 }),
            UniswapOracleV3SingleTwapBase.OracleParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.UNI_ERC20,
                uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 338_921_318_918_776_963_008_316_417_223_772_858_717);
        assertEq(((price * 1e18) / 1e18) / 1e36, 338); // 338 UNI per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUniWithBadDataFromUni() public {
        DualOracleChainlinkUniV3 oracle = oracleFactory.createDualOracleChainlinkUniV3(
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({ baseMaxDelayPrimary: 0, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 10, quoteMaxDelaySecondary: 0 }),
            UniswapOracleV3SingleTwapBase.OracleParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.UNI_ERC20,
                uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 342_170_188_147_668_813_010_937_084_335_830_514_402);
        assertEq(((price * 1e18) / 1e18) / 1e36, 342); // 342 UNI per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_stablePriceOracle_success() public {
        StablePriceOracle oracle = oracleFactory.createStableOracle(1e36);
        assertTrue(oracleFactory.isDahliaOracle(address(oracle)));
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1e36);
        assertEq(_isBadData, false);
    }
}
