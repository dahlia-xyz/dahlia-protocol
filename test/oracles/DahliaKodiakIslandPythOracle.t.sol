// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//import { StaticOracle } from "@uniswap-v3-oracle/solidity/contracts/StaticOracle.sol";
import { IStaticOracle } from "@uniswap-v3-oracle/solidity/interfaces/IStaticOracle.sol";
//import {IStaticOracle} from "./uniswap-static-oracle/interfaces/IStaticOracle.sol";
//import {StaticOracle} from "./uniswap-static-oracle/contracts/StaticOracle.sol";

import { DahliaKodiakIslandPythOracle, IKodiakIsland } from "src/oracles/contracts/DahliaKodiakIslandPythOracle.sol";
import { DahliaKodiakIslandPythOracleFactory } from "src/oracles/contracts/DahliaKodiakIslandPythOracleFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { Berachain } from "test/oracles/Constants.sol";

import { IERC20 } from "@forge-std/interfaces/IERC20.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { Test, Vm } from "@forge-std/Test.sol";

import { console } from "@forge-std/console.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";
import { Timelock } from "src/oracles/contracts/Timelock.sol";
import { TestContext } from "test/common/TestContext.sol";

contract DahliaKodiakIslandPythOracleTest is Test {
    using BoundUtils for Vm;
    using SafeTransferLib for address;
    using SafeCastLib for int256;

    TestContext ctx;
    DahliaKodiakIslandPythOracle oracle;
    DahliaKodiakIslandPythOracle.Delays delays;

    uint128 internal constant LIQUIDITY_AMOUNT = 10_000e18;

    struct SwapCallbackData {
        address tokenIn;
        address tokenOut;
    }

    struct MintCallbackData {
        address token0;
        address token1;
    }

    function setUp() public {
        vm.createSelectFork("berachain", 1_436_384);
        ctx = new TestContext(vm);
        delays = DahliaKodiakIslandPythOracle.Delays({ baseToken0MaxDelay: 86_400, baseToken1MaxDelay: 86_400, quoteMaxDelay: 86_400 });
        DahliaKodiakIslandPythOracleFactory factory = ctx.createKodiakIslandPythOracleFactory();
        oracle = DahliaKodiakIslandPythOracle(
            factory.createKodiakIslandPythOracle(
                DahliaKodiakIslandPythOracle.Params({
                    kodiakIsland: Berachain.WBERA_HONEY_KODIAK_ISLAND,
                    baseToken0Feed: 0x962088abcfdbdb6e30db2e340c8cf887d9efb311b1f2f17b155a63dbb6d40265, // BERA
                    baseToken1Feed: 0xf67b033925d73d43ba4401e00308d9b0f26ab4fbd1250e8b5407b9eaade7e1f4, // HONEY
                    quoteToken: Berachain.USDCe_ERC20,
                    quoteFeed: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a // USDC
                 }),
                delays,
                300,
                5
            )
        );
    }

    function test_kodiak_island_oracle_pythWithMaxDelay_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        // TODO Check correct number
        assertEq(_price, 2_295_212_787_654_355_649_510_749_137_872_409); // 6_082_235_249_584_020_861_099_252 vs 6_441_537_247_382_733_526_541_680
        assertEq(_isBadData, false);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));

        uint256 amountToPay;
        if (amount0Delta > 0) {
            amountToPay = amount0Delta.toUint256();
        } else {
            amountToPay = amount1Delta.toUint256();
        }

        pay(data.tokenIn, address(this), msg.sender, amountToPay);
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(address token, address payer, address recipient, uint256 value) internal {
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            token.safeTransfer(recipient, value);
        } else {
            // pull payment
            token.safeTransferFrom(payer, recipient, value);
        }
    }

    function test_uniswap_v3_swap_attack() public {
        (, bool beforeIsBadData) = oracle.getPrice();
        assertEq(beforeIsBadData, false);

        swapAttack();

        (, bool afterIsBadData) = oracle.getPrice();

        //        assertEq(beforePrice, afterPrice);
        //        assertApproxEqRel(beforePrice, afterPrice, 0.01e18);
        assertEq(afterIsBadData, true);
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata _data) external {
        //        require(amount0Owed > 0 && amount1Owed > 0); // swaps entirely within 0-liquidity regions are not supported
        MintCallbackData memory data = abi.decode(_data, (MintCallbackData));
        pay(data.token0, address(this), msg.sender, amount0Owed);
        pay(data.token1, address(this), msg.sender, amount1Owed);
    }

    function swapAttack() internal {
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());
        (uint256 underlying0, uint256 underlying1) = kodiakIsland.getUnderlyingBalances();

        IUniswapV3Pool pool = IUniswapV3Pool(kodiakIsland.pool());
        address token0 = pool.token0();
        address token1 = pool.token1();

        deal(token0, address(this), underlying0 + 10_000_000e18);
        uint256 token0AmountBefore = IERC20(token0).balanceOf(address(this));
        uint256 token1AmountBefore = IERC20(token1).balanceOf(address(this));

        uint160 sqrtPriceLimitX96 = 4_295_128_739 + 1;

        int256 amountSpecified = -int256(underlying1); // target draining token0

        SwapCallbackData memory data = SwapCallbackData({ tokenIn: token0, tokenOut: token1 });

        pool.swap(address(this), true, amountSpecified, sqrtPriceLimitX96, abi.encode(data));

        (, uint256 underlying1PostSwap) = kodiakIsland.getUnderlyingBalances();

        //        assertEq(underlying1PostSwap, 0, "token1 should be drained");

        uint256 token0AmountAfter = IERC20(token0).balanceOf(address(this));
        uint256 token1AmountAfter = IERC20(token1).balanceOf(address(this));

        assertGt(token0AmountBefore, token0AmountAfter);
        assertGt(token1AmountAfter, token1AmountBefore);
    }

    function swapAttackToken0() internal {
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());
        (uint256 underlying0, uint256 underlying1) = kodiakIsland.getUnderlyingBalances();

        IUniswapV3Pool pool = IUniswapV3Pool(kodiakIsland.pool());
        address token0 = pool.token0();
        address token1 = pool.token1();

        deal(token1, address(this), underlying1 + 10_000_000_000e18);
        uint256 token0AmountBefore = IERC20(token0).balanceOf(address(this));
        uint256 token1AmountBefore = IERC20(token1).balanceOf(address(this));

        uint160 sqrtPriceLimitX96 = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

        int256 amountSpecified = -int256(underlying0); // target draining token0

        SwapCallbackData memory data = SwapCallbackData({ tokenIn: token1, tokenOut: token0 });

        pool.swap(address(this), false, amountSpecified, sqrtPriceLimitX96, abi.encode(data));

        //        (, uint256 underlying1PostSwap) = kodiakIsland.getUnderlyingBalances();

        //        assertEq(underlying1PostSwap, 0, "token1 should be drained");

        uint256 token0AmountAfter = IERC20(token0).balanceOf(address(this));
        uint256 token1AmountAfter = IERC20(token1).balanceOf(address(this));

        assertGt(token0AmountAfter, token0AmountBefore);
        assertGt(token1AmountBefore, token1AmountAfter);
    }

    function returnTokensAfterSwapAttack(uint256 token0BalanceBefore, uint256 token1BalanceBefore) internal {
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());
        //        pool.burn(tickLower, tickUpper, liquidityAmount);
        kodiakIsland.burn(LIQUIDITY_AMOUNT, address(this));

        IUniswapV3Pool pool = IUniswapV3Pool(kodiakIsland.pool());
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 token0BalanceFinal = IERC20(token0).balanceOf(address(this));
        uint256 token1BalanceFinal = IERC20(token1).balanceOf(address(this));

        assertApproxEqAbs(token0BalanceFinal, token0BalanceBefore, 10);
        assertApproxEqAbs(token1BalanceFinal, token1BalanceBefore, 10);
    }

    function test_uniswap_v3_liquidity_attack() public {
        uint256 a = 100;
        uint256 b = 110;
        uint256 maxPercentDelta = 0.1e18;

        assertApproxEqRel(a, b, maxPercentDelta);

        (uint256 beforePrice, bool beforeIsBadData) = oracle.getPrice();
        assertEq(beforeIsBadData, false);
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());

        IUniswapV3Pool pool = IUniswapV3Pool(kodiakIsland.pool());
        address token0 = pool.token0();
        address token1 = pool.token1();

        deal(token0, address(this), 10_000_000e18);
        deal(token1, address(this), 10_000_000e18);
        uint256 token0BalanceBefore = IERC20(token0).balanceOf(address(this));
        uint256 token1BalanceBefore = IERC20(token1).balanceOf(address(this));

        //        MintCallbackData memory mintCallbackData = MintCallbackData({ token0: token0, token1: token1 });

        uint128 liquidityAmount = 10_000e18;
        //        int24 tickLower = 7;
        //        int24 tickUpper = 8;

        //        pool.mint(address(this), tickLower, tickUpper, liquidityAmount, abi.encode(mintCallbackData));

        IERC20(token0).approve(address(kodiakIsland), type(uint256).max);
        IERC20(token1).approve(address(kodiakIsland), type(uint256).max);

        kodiakIsland.mint(liquidityAmount, address(this));

        uint256 token0BalanceAfter = IERC20(token0).balanceOf(address(this));
        uint256 token1BalanceAfter = IERC20(token1).balanceOf(address(this));

        assertLt(token0BalanceAfter, token0BalanceBefore);
        assertLt(token1BalanceAfter, token0BalanceBefore);

        (uint256 afterPrice, bool afterIsBadData) = oracle.getPrice();

        assertEq(afterIsBadData, false);

        //        assertEq(beforePrice, afterPrice);
        //        assertGe(beforePrice + (beforePrice * 1) / 100, afterPrice);
        //        assertLe(beforePrice - (beforePrice * 1) / 100, afterPrice);
        assertApproxEqRel(beforePrice, afterPrice, 0.01e18);

        //        pool.burn(tickLower, tickUpper, liquidityAmount);
        kodiakIsland.burn(liquidityAmount, address(this));

        uint256 token0BalanceFinal = IERC20(token0).balanceOf(address(this));
        uint256 token1BalanceFinal = IERC20(token1).balanceOf(address(this));

        assertApproxEqAbs(token0BalanceFinal, token0BalanceBefore, 10);
        assertApproxEqAbs(token1BalanceFinal, token1BalanceBefore, 10);

        (uint256 finalPrice, bool finalIsBadData) = oracle.getPrice();

        assertEq(finalIsBadData, false);

        //        assertEq(afterPrice, finalPrice);
        assertApproxEqRel(afterPrice, finalPrice, 0.01e18);
    }

    function test_kodiak_island_oracle_pythWithMaxDelay_setDelayNotOwner() public {
        vm.startPrank(ctx.ALICE());

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ctx.ALICE()));
        oracle.setMaximumOracleDelays(DahliaKodiakIslandPythOracle.Delays({ baseToken0MaxDelay: 1, baseToken1MaxDelay: 2, quoteMaxDelay: 3 }));
        vm.stopPrank();
    }

    function test_kodiak_island_oracle_pythWithMaxDelay_setDelayOwner() public {
        vm.pauseGasMetering();
        DahliaKodiakIslandPythOracle.Delays memory newDelays =
            DahliaKodiakIslandPythOracle.Delays({ baseToken0MaxDelay: 1, baseToken1MaxDelay: 2, quoteMaxDelay: 3 });

        string memory signature = "setMaximumOracleDelays((uint256,uint256,uint256))";
        bytes memory data = abi.encode(newDelays);
        console.logBytes(data);
        Timelock timelock = Timelock(oracle.owner());
        uint256 eta = block.timestamp + timelock.delay() + 1;
        uint256 value = 0;
        bytes32 expectedTxHash = keccak256(abi.encode(address(oracle), value, signature, data, eta));

        vm.startPrank(ctx.OWNER());
        vm.resumeGasMetering();

        vm.expectEmit(true, true, false, true, address(timelock));
        emit Timelock.QueueTransaction(expectedTxHash, address(oracle), value, signature, data, eta);

        bytes32 txHash = timelock.queueTransaction(address(oracle), value, signature, data, eta);
        assertEq(txHash, expectedTxHash);

        skip(timelock.delay() + 1);

        vm.expectEmit(true, true, true, true, address(oracle));
        emit DahliaKodiakIslandPythOracle.MaximumOracleDelaysUpdated(delays, newDelays);

        vm.expectEmit(true, true, false, true, address(timelock));
        emit Timelock.ExecuteTransaction(txHash, address(oracle), value, signature, data, eta);

        timelock.executeTransaction(address(oracle), value, signature, data, eta);

        vm.pauseGasMetering();
        assertEq(oracle.baseToken0MaxDelay(), 1);
        assertEq(oracle.baseToken1MaxDelay(), 2);
        assertEq(oracle.quoteMaxDelay(), 3);
    }

    function test_static_oracle_during_swap_attack() public {
        IStaticOracle staticOracle = IStaticOracle(deployCode("StaticOracle.sol:StaticOracle", abi.encode(0xD84CBf0B02636E7f53dB9E5e45A616E05d710990, 4)));
        //        IStaticOracle staticOracle = new StaticOracle(0xD84CBf0B02636E7f53dB9E5e45A616E05d710990, 4);
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());
        address uniswapPool = kodiakIsland.pool();
        address[] memory pools = new address[](1);
        pools[0] = uniswapPool;
        uint256 beforePrice = staticOracle.quoteSpecificPoolsWithTimePeriod({
            baseAmount: 1e36,
            baseToken: kodiakIsland.token0(),
            quoteToken: kodiakIsland.token1(),
            pools: pools,
            period: 60
        });

        swapAttack();

        uint256 afterPrice = staticOracle.quoteSpecificPoolsWithTimePeriod({
            baseAmount: 1e36,
            baseToken: kodiakIsland.token0(),
            quoteToken: kodiakIsland.token1(),
            pools: pools,
            period: 60
        });

        assertApproxEqRel(beforePrice, afterPrice, 0.01e18);
    }

    function test_getAvgPrice_during_swap_attack() public {
        IKodiakIsland kodiakIsland = IKodiakIsland(oracle.KODIAK_ISLAND());
        vm.forward(100);
        uint160 beforePrice = kodiakIsland.getAvgPrice(60);

        swapAttackToken0();

        uint160 afterPrice = kodiakIsland.getAvgPrice(60);

        assertApproxEqRel(beforePrice, afterPrice, 0.01e18);
    }
}
