// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { DahliaPythV2Oracle } from "src/oracles/contracts/DahliaPythV2Oracle.sol";
import { DahliaPythV2OracleFactory } from "src/oracles/contracts/DahliaPythV2OracleFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Sonic } from "test/oracles/Constants.sol";

contract DahliaPythV2OracleSonicTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    DahliaPythV2OracleFactory factory;

    function setUp() public {
        vm.createSelectFork("sonic", 13_475_300);
        ctx = new TestContext(vm);
        factory = ctx.createPythV2OracleFactory(Sonic.PYTH_STATIC_ORACLE_ADDRESS);
    }

    function test_oracle_pythV2WSTKSCUSD_USDC_success() public {
        DahliaPythV2Oracle oracle;
        DahliaPythV2Oracle.Delays memory delays;
        bytes32 WSTK_SCUSD_FEED = 0xcaed0964240861da425cf03fae9737473f6f031fb80cbbd73c3fb8cddd7a2204;
        bytes32 SCUSD_FEED = 0x316b1536978bee10c47b3c74c0b3995aabae973a3351621680a2aa383aca77b8;
        bytes32 USDC_FEED = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        delays =
            DahliaPythV2Oracle.Delays({ baseMaxDelayPrimary: 86_400, baseMaxDelaySecondary: 86_400, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 });
        oracle = DahliaPythV2Oracle(
            factory.createPythV2Oracle(
                DahliaPythV2Oracle.Params({
                    baseToken: Sonic.ERC20_WSTK_SCUSD,
                    // https://www.pyth.network/price-feeds/crypto-wstkscusd-scusd-rr
                    baseFeedPrimary: WSTK_SCUSD_FEED,
                    // https://www.pyth.network/price-feeds/crypto-scusd-usd
                    baseFeedSecondary: SCUSD_FEED,
                    quoteToken: Sonic.ERC20_USDC,
                    // https://www.pyth.network/price-feeds/crypto-usdc-usd
                    quoteFeedPrimary: USDC_FEED,
                    quoteFeedSecondary: bytes32(0)
                }),
                delays
            )
        );

        PythStructs.Price memory result1 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(WSTK_SCUSD_FEED, 86_400);
        assertEq(result1.price, 100_097_864, "WSTKSCUSDC price"); // 1.00097864
        assertEq(result1.expo, -8);
        PythStructs.Price memory result2 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(SCUSD_FEED, 86_400);
        assertEq(result2.price, 99_926_289, "SCUSD price"); // 0.99926289
        assertEq(result2.expo, -8);
        PythStructs.Price memory result3 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(USDC_FEED, 86_400);
        assertEq(result3.price, 99_989_950, "USDC_FEED price"); // 0.99989950
        assertEq(result3.expo, -8);
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1_000_341_342_939_635_033_320_848_745_298_902_539);
        assertEq(_isBadData, false);
        uint256 one = 10 ** IERC20Metadata(Sonic.ERC20_WSTK_SCUSD).decimals();
        uint256 result = MarketMath.calcMaxBorrowAssets(_price, one, Constants.LLTV_100_PERCENT);
        assertEq(result, 1_000_341);
        assertEq(one, 1_000_000);
    }

    function test_oracle_pythV2_WSTKSCETH_USDC_success() public {
        DahliaPythV2Oracle oracle;
        DahliaPythV2Oracle.Delays memory delays;
        bytes32 WSTKSCETH_SCETH_FEED = 0xb680422b70915df562e4802bd8679112ff0f6b0a29ec2c3762ae2720eda01e58;
        bytes32 SCETH_FEED = 0x8bb5e69ed1ab19642a0e7e851b1ed7b3579d0548bc8ddd1077b0d9476bb1dabc;
        bytes32 USDC_FEED = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        delays =
            DahliaPythV2Oracle.Delays({ baseMaxDelayPrimary: 86_400, baseMaxDelaySecondary: 86_400, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 });
        oracle = DahliaPythV2Oracle(
            factory.createPythV2Oracle(
                DahliaPythV2Oracle.Params({
                    baseToken: Sonic.ERC20_WSTK_SCETH,
                    // https://www.pyth.network/price-feeds/crypto-wstkscusd-scusd-rr
                    baseFeedPrimary: WSTKSCETH_SCETH_FEED,
                    // https://www.pyth.network/price-feeds/crypto-scusd-usd
                    baseFeedSecondary: SCETH_FEED,
                    quoteToken: Sonic.ERC20_USDC,
                    // https://www.pyth.network/price-feeds/crypto-usdc-usd
                    quoteFeedPrimary: USDC_FEED,
                    quoteFeedSecondary: bytes32(0)
                }),
                delays
            )
        );

        PythStructs.Price memory result1 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(WSTKSCETH_SCETH_FEED, 86_400);
        assertEq(result1.price, 100_022_673, "WSTK_SCETH_FEED price"); // 1.00097864
        assertEq(result1.expo, -8);
        assertEq(result1.expo, -8);
        PythStructs.Price memory result2 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(SCETH_FEED, 86_400);
        assertEq(result2.price, 188_537_403_335, "SCETH_FEED price"); // 0.99926289
        assertEq(result2.expo, -8);
        PythStructs.Price memory result3 = IPyth(Sonic.PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(USDC_FEED, 86_400);
        assertEq(result3.price, 99_989_950, "USDC_FEED price"); // 0.99989950
        assertEq(result3.expo, -8);
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1_885_991_046_304_735_071_374_673_154);
        assertEq(_isBadData, false);
        uint256 one = 10 ** IERC20Metadata(Sonic.ERC20_WSTK_SCETH).decimals();
        uint256 result = MarketMath.calcMaxBorrowAssets(_price, one, Constants.LLTV_100_PERCENT);
        assertEq(result, 1_885_991_046, "can borrow USDC for 1 WSTSCETH");
        assertEq(one, 1_000_000_000_000_000_000, "1 WSTSCETH");
    }
}
