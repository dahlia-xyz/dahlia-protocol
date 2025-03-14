// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { console } from "@forge-std/console.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { DahliaPythV2Oracle } from "src/oracles/contracts/DahliaPythV2Oracle.sol";
import { DahliaPythV2OracleFactory } from "src/oracles/contracts/DahliaPythV2OracleFactory.sol";
import { Timelock } from "src/oracles/contracts/Timelock.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Mainnet } from "test/oracles/Constants.sol";

contract DahliaPythV2OracleTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    DahliaPythV2Oracle oracle;
    DahliaPythV2Oracle.Delays delays;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        delays = DahliaPythV2Oracle.Delays({ baseMaxDelayPrimary: 86_400, baseMaxDelaySecondary: 0, quoteMaxDelayPrimary: 86_400, quoteMaxDelaySecondary: 0 });
        DahliaPythV2OracleFactory factory = ctx.createPythV2OracleFactory(Mainnet.PYTH_STATIC_ORACLE_ADDRESS);
        oracle = DahliaPythV2Oracle(
            factory.createPythV2Oracle(
                DahliaPythV2Oracle.Params({
                    baseToken: Mainnet.WETH_ERC20,
                    baseFeedPrimary: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace,
                    baseFeedSecondary: bytes32(0),
                    quoteToken: Mainnet.UNI_ERC20,
                    quoteFeedPrimary: 0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501,
                    quoteFeedSecondary: bytes32(0)
                }),
                delays
            )
        );
    }

    function test_oracle_pythV2WithMaxDelay_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 349_637_857_989_881_860_139_699_580_376_458_729_677);
        assertEq(_isBadData, false);
        uint256 one = 10 ** IERC20Metadata(Mainnet.WETH_ERC20).decimals();
        uint256 two = MarketMath.calcMaxBorrowAssets(_price, one, Constants.LLTV_100_PERCENT);
        assertEq(two, 349_637_857_989_881_860_139);
        assertEq(one, 1_000_000_000_000_000_000);
    }

    function test_oracle_pythV2WithMaxDelay_setDelayNotOwner() public {
        vm.startPrank(ctx.ALICE());

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ctx.ALICE()));
        oracle.setMaximumOracleDelays(
            DahliaPythV2Oracle.Delays({ quoteMaxDelayPrimary: 1, quoteMaxDelaySecondary: 1, baseMaxDelayPrimary: 2, baseMaxDelaySecondary: 2 })
        );
        vm.stopPrank();
    }

    function test_oracle_pythV2WithMaxDelay_setDelayOwner() public {
        vm.pauseGasMetering();
        DahliaPythV2Oracle.Delays memory newDelays =
            DahliaPythV2Oracle.Delays({ quoteMaxDelayPrimary: 1, quoteMaxDelaySecondary: 3, baseMaxDelayPrimary: 2, baseMaxDelaySecondary: 4 });

        string memory signature = "setMaximumOracleDelays((uint256,uint256,uint256,uint256))";
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
        emit DahliaPythV2Oracle.MaximumOracleDelaysUpdated(delays, newDelays);

        vm.expectEmit(true, true, false, true, address(timelock));
        emit Timelock.ExecuteTransaction(txHash, address(oracle), value, signature, data, eta);

        timelock.executeTransaction(address(oracle), value, signature, data, eta);

        vm.pauseGasMetering();
        assertEq(oracle.quoteMaxDelayPrimary(), 1);
        assertEq(oracle.quoteMaxDelaySecondary(), 3);
        assertEq(oracle.baseMaxDelayPrimary(), 2);
        assertEq(oracle.baseMaxDelaySecondary(), 4);
    }
}
