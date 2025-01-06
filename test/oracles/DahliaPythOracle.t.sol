// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { DahliaPythOracle } from "src/oracles/contracts/DahliaPythOracle.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Mainnet } from "test/oracles/Constants.sol";

contract DahliaPythOracleTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    DahliaPythOracle oracle;
    DahliaPythOracle.Delays delays;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        address owner = ctx.createWallet("OWNER");
        delays = DahliaPythOracle.Delays({ baseMaxDelay: 86_400, quoteMaxDelay: 86_400 });
        oracle = new DahliaPythOracle(
            owner,
            DahliaPythOracle.Params({
                baseToken: Mainnet.WETH_ERC20,
                baseFeed: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace,
                quoteToken: Mainnet.UNI_ERC20,
                quoteFeed: 0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501
            }),
            delays,
            Mainnet.PYTH_STATIC_ORACLE_ADDRESS
        );
    }

    function test_oracle_pythWithMaxDelay_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 349_637_857_989_881_860_139_699_580_376_458_729_677);
        assertEq(_isBadData, false);
    }

    function test_oracle_pythWithMaxDelay_setDelayNotOwner() public {
        address alice = ctx.createWallet("ALICE");
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(alice)));
        oracle.setMaximumOracleDelays(DahliaPythOracle.Delays({ quoteMaxDelay: 1, baseMaxDelay: 2 }));
        vm.stopPrank();
    }

    function test_oracle_pythWithMaxDelay_setDelayOwner() public {
        vm.pauseGasMetering();
        address owner = ctx.createWallet("OWNER");
        DahliaPythOracle.Delays memory newDelays = DahliaPythOracle.Delays({ quoteMaxDelay: 1, baseMaxDelay: 2 });
        vm.expectEmit(true, true, true, true, address(oracle));
        emit DahliaPythOracle.MaximumOracleDelaysUpdated(delays, newDelays);
        vm.prank(owner);
        vm.resumeGasMetering();
        oracle.setMaximumOracleDelays(newDelays);
        vm.pauseGasMetering();
        assertEq(oracle.quoteMaxDelay(), 1);
        assertEq(oracle.baseMaxDelay(), 2);
    }
}
