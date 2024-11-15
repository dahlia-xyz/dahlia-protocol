// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { StablePriceOracle } from "src/oracles/contracts/StablePriceOracle.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

contract ChainlinkOracleWithMaxDelayTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    StablePriceOracle oracle;

    function setUp() public {
        ctx = new TestContext(vm);
        oracle = new StablePriceOracle(1e36);
    }

    function test_oracle_stablePriceOracle_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 1e36);
        assertEq(_isBadData, false);
    }
}
