// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Test, Vm} from "@forge-std/Test.sol";
import {
    ChainlinkOracleMaxDelayParams,
    ChainlinkOracleParams,
    ChainlinkWithMaxDelay,
    DualOracleChainlinkUniV3,
    OracleFactory
} from "src/oracles/contracts/OracleFactory.sol";
import {UniswapOraclerParams, UniswapV3SingleTwap} from "src/oracles/contracts/UniswapV3SingleTwap.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {Mainnet} from "test/oracles/Constants.sol";

contract OracleFactoryTest is Test {
    using BoundUtils for Vm;

    uint256 ORACLE_PRECISION = 1e18;
    TestContext ctx;
    address oracleFactory;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        oracleFactory = ctx.createOracleFactory();
    }

    function test_oracleFactory_chainlink() public {
        /// @dev USDC is collateral, WBTC is loan, then result is 0.000016xxx
        ChainlinkWithMaxDelay oracle = OracleFactory(oracleFactory).createChainlinkOracle(
            ChainlinkOracleParams({
                baseToken: Mainnet.USDC_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.WBTC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.BTC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(Mainnet.WBTC_BTC_CHAINLINK_ORACLE)
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 86400
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 1611859162144102979080952870358934);
        assertEq(isBadData, false);
    }

    function test_oracleFactory_paxg_chainlink() public {
        /// @dev PAXG is collateral, USDC is loan, then result is 2617
        ChainlinkWithMaxDelay oracle = OracleFactory(oracleFactory).createChainlinkOracle(
            ChainlinkOracleParams({
                baseToken: 0x45804880De22913dAFE09f4980848ECE6EcbAf78,
                baseFeedPrimary: AggregatorV3Interface(0x7C4561Bb0F2d6947BeDA10F667191f6026E7Ac0c),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2617340351185118511851185118);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2617); // 2617 USDC per 1 PAXG
        assertEq(isBadData, false);
    }

    function test_oracleFactory_wethUsdc() public {
        ChainlinkWithMaxDelay oracle = OracleFactory(oracleFactory).createChainlinkOracle(
            ChainlinkOracleParams({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.ETH_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2404319134993499349934993499);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2404); // 2404 USDC per 1 ETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_uniswap_wethUsdc() public {
        UniswapV3SingleTwap oracle = OracleFactory(oracleFactory).createUniswapOracle(
            UniswapOraclerParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.USDC_ERC20,
                uniswapV3PairAddress: Mainnet.WETH_USDC_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2412486481775144671894069994);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2412); // 2412 USDC per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUsdc() public {
        DualOracleChainlinkUniV3 oracle = OracleFactory(oracleFactory).createDualOracleChainlinkUniV3(
            ChainlinkOracleParams({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.ETH_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            }),
            UniswapOraclerParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.USDC_ERC20,
                uniswapV3PairAddress: Mainnet.WETH_USDC_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 2404319134993499349934993499);
        assertEq(((price * 1e18) / 1e6) / 1e36, 2404); // 2404 USDC per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUniFromChainlink() public {
        DualOracleChainlinkUniV3 oracle = OracleFactory(oracleFactory).createDualOracleChainlinkUniV3(
            ChainlinkOracleParams({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 0,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            }),
            UniswapOraclerParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.UNI_ERC20,
                uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 338921318918776963008316417223772858717);
        assertEq(((price * 1e18) / 1e18) / 1e36, 338); // 338 UNI per 1 WETH
        assertEq(isBadData, false);
    }

    function test_oracleFactory_dual_wethUniWithBadDataFromUni() public {
        DualOracleChainlinkUniV3 oracle = OracleFactory(oracleFactory).createDualOracleChainlinkUniV3(
            ChainlinkOracleParams({
                baseToken: Mainnet.WETH_ERC20,
                baseFeedPrimary: AggregatorV3Interface(address(0)),
                baseFeedSecondary: AggregatorV3Interface(address(0)),
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.UNI_WETH_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 0,
                baseMaxDelaySecondary: 0,
                quoteMaxDelayPrimary: 10,
                quoteMaxDelaySecondary: 0
            }),
            UniswapOraclerParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.UNI_ERC20,
                uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL,
                twapDuration: 900
            })
        );
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(price, 342170188147668813010937084335830514402);
        assertEq(((price * 1e18) / 1e18) / 1e36, 342); // 342 UNI per 1 WETH
        assertEq(isBadData, false);
    }
}
