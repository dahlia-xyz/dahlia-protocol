// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Test, Vm} from "@forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ChainlinkOracleMaxDelayParams,
    ChainlinkOracleParams,
    ChainlinkWithMaxDelay
} from "src/oracles/contracts/ChainlinkWithMaxDelay.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {Mainnet} from "test/oracles/Constants.sol";

contract ChainlinkWithMaxDelayTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    ChainlinkWithMaxDelay oracle;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        address owner = ctx.createWallet("OWNER");

        oracle = new ChainlinkWithMaxDelay(
            owner,
            ChainlinkOracleParams({
                baseToken: Mainnet.WBTC_ERC20,
                baseFeedPrimary: AggregatorV3Interface(Mainnet.BTC_USD_CHAINLINK_ORACLE),
                baseFeedSecondary: AggregatorV3Interface(Mainnet.WBTC_BTC_CHAINLINK_ORACLE),
                quoteToken: Mainnet.USDC_ERC20,
                quoteFeedPrimary: AggregatorV3Interface(Mainnet.USDC_USD_CHAINLINK_ORACLE),
                quoteFeedSecondary: AggregatorV3Interface(address(0))
            }),
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 86400,
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            })
        );
    }

    function test_oracle_chainlinkWithMaxDelay_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 620401598034033622037203720372037203720);
        assertEq(_isBadData, false);
    }

    function test_oracle_chainlinkWithMaxDelay_setDelayNotOwner() public {
        address alice = ctx.createWallet("ALICE");
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(alice)));
        oracle.setMaximumOracleDelays(
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 1,
                baseMaxDelaySecondary: 2,
                quoteMaxDelayPrimary: 3,
                quoteMaxDelaySecondary: 0
            })
        );
        vm.stopPrank();
    }

    function test_oracle_chainlinkWithMaxDelay_setDelayOwner() public {
        address owner = ctx.createWallet("OWNER");
        vm.startPrank(owner);

        oracle.setMaximumOracleDelays(
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 1,
                baseMaxDelaySecondary: 2,
                quoteMaxDelayPrimary: 3,
                quoteMaxDelaySecondary: 0
            })
        );

        vm.stopPrank();
        (uint256 baseMaxDelayPrimary, uint256 baseMaxDelaySecondary,,) = oracle.maxDelays();
        assertEq(baseMaxDelayPrimary, 1);
        assertEq(baseMaxDelaySecondary, 2);
    }

    function test_oracle_chainlinkWithMaxDelay_checkBadData() public {
        address owner = ctx.createWallet("OWNER");
        vm.startPrank(owner);

        oracle.setMaximumOracleDelays(
            ChainlinkOracleMaxDelayParams({
                baseMaxDelayPrimary: 86400,
                baseMaxDelaySecondary: 1000, // <- 1000 second for good value
                quoteMaxDelayPrimary: 86400,
                quoteMaxDelaySecondary: 0
            })
        );
        vm.stopPrank();

        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 620401598034033622037203720372037203720);
        assertEq(_isBadData, true);
    }
}
