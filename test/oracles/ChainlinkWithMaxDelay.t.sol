// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Test, Vm } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ChainlinkOracleWithMaxDelayBase } from "src/oracles/abstracts/ChainlinkOracleWithMaxDelayBase.sol";
import { ChainlinkOracleWithMaxDelay } from "src/oracles/contracts/ChainlinkOracleWithMaxDelay.sol";
import { IChainlinkOracleWithMaxDelay } from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Mainnet } from "test/oracles/Constants.sol";

contract ChainlinkOracleWithMaxDelayTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    ChainlinkOracleWithMaxDelay oracle;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        address owner = ctx.createWallet("OWNER");

        oracle = new ChainlinkOracleWithMaxDelay(
            owner,
            ChainlinkOracleWithMaxDelayBase.Params({
                baseToken: Mainnet.WBTC_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.BTC_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(Mainnet.WBTC_BTC_CHAINLINK_ORACLE),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 86_400,
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 0
            })
        );
    }

    function test_oracle_chainlinkWithMaxDelay_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 620_401_598_034_033_622_037_203_720_372_037_203_720);
        assertEq(_isBadData, false);
    }

    function test_oracle_chainlinkWithMaxDelay_setDelayNotOwner() public {
        address alice = ctx.createWallet("ALICE");
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(alice)));
        oracle.setMaximumOracleDelays(
            IChainlinkOracleWithMaxDelay.Delays({ baseMaxDelayPrimary: 1, baseMaxDelaySecondary: 2, quoteMaxDelayPrimary: 3, quoteMaxDelaySecondary: 0 })
        );
        vm.stopPrank();
    }

    function test_oracle_chainlinkWithMaxDelay_setDelayOwner() public {
        address owner = ctx.createWallet("OWNER");
        vm.startPrank(owner);

        oracle.setMaximumOracleDelays(
            IChainlinkOracleWithMaxDelay.Delays({ baseMaxDelayPrimary: 1, baseMaxDelaySecondary: 2, quoteMaxDelayPrimary: 3, quoteMaxDelaySecondary: 0 })
        );

        vm.stopPrank();
        IChainlinkOracleWithMaxDelay.Delays memory delays = oracle.maxDelays();
        assertEq(delays.baseMaxDelayPrimary, 1);
        assertEq(delays.baseMaxDelaySecondary, 2);
    }

    function test_oracle_chainlinkWithMaxDelay_checkBadData() public {
        address owner = ctx.createWallet("OWNER");
        vm.startPrank(owner);

        oracle.setMaximumOracleDelays(
            IChainlinkOracleWithMaxDelay.Delays({
                baseMaxDelayPrimary: 86_400,
                baseMaxDelaySecondary: 1000, // <- 1000 second for good value
                quoteMaxDelayPrimary: 86_400,
                quoteMaxDelaySecondary: 0
            })
        );
        vm.stopPrank();

        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 620_401_598_034_033_622_037_203_720_372_037_203_720);
        assertEq(_isBadData, true);
    }
}
