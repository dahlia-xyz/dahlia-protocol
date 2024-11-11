// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test, Vm } from "forge-std/Test.sol";

import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";

contract MathCalculationsTest is Test {
    using BoundUtils for Vm;

    function test_unit_math_feeFromInterest() public pure {
        assertEq(InterestImpl.calcFeeSharesFromInterest(10_000_000, 10_000_000, 1000, 0.01e5), 9);
        assertEq(InterestImpl.calcFeeSharesFromInterest(10_000_000, 10_000_000, 1000, 0), 0);
        assertEq(InterestImpl.calcFeeSharesFromInterest(1e18, 1e24, 1e6, 0.02e5), 19_999_999_999);
        assertEq(InterestImpl.calcFeeSharesFromInterest(1e18, 1e24, 100, 0.02e5), 1_999_999);
        assertEq(InterestImpl.calcFeeSharesFromInterest(1e6, 1e12, 1, 0.02e5), 19_999);
        assertEq(InterestImpl.calcFeeSharesFromInterest(1e2, 1e8, 1, 0.002e5), 1980);
        // TODO: add more tests
    }
}
