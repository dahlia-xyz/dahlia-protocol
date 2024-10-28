// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {VariableIrm} from "src/irm/contracts/VariableIrm.sol";
import {IrmConstants} from "src/irm/helpers/IrmConstants.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestConstants} from "test/common/TestConstants.sol";

contract VariableIrmTest is Test {
    VariableIrm internal rate;

    using BoundUtils for Vm;
    using Strings for uint256;
    using SharesMathLib for uint256;

    uint64 constant ZERO_UTIL_RATE = 158247046;
    uint64 constant MIN_FULL_UTIL_RATE = 1582470460;
    uint64 constant MAX_FULL_UTIL_RATE = 3164940920000;

    struct NewRateSet {
        uint256 d; //deltaTime
        uint256 u; //utilization
        uint64 i; //oldFullUtilizationInterest
        uint256 newRPS; //expectedRatePerSec
        uint256 newUtl; //expectedFullUtilizationInterest
    }

    struct InterestSet {
        uint256 deltaTime;
        uint256 totalLendAssets;
        uint256 totalBorrowAssets;
        uint64 oldFullUtilizationInterest;
        uint256 expectedInterestEarnedAssets;
        uint256 expectedRatePerSec;
        uint256 expectedFullUtilizationInterest;
    }

    NewRateSet[] internal rates;

    function processRateTest(function (NewRateSet memory, string memory) f) internal {
        uint256 length = rates.length;
        for (uint256 i = 0; i < length;) {
            f(rates[i], i.toString());
            i += 1;
        }
    }

    InterestSet[] internal interests;

    function processInterestTest(function (InterestSet memory, string memory) f) internal {
        uint256 length = interests.length;
        for (uint256 i = 0; i < length;) {
            f(interests[i], i.toString());
            i += 1;
        }
    }

    function setUp() public {
        // taken from https://etherscan.io/address/0x18500cb1f2fe7a40ebda393383a0b8548a31f261#readContract
        rate = new VariableIrm(
            VariableIrm.Config({
                minTargetUtilization: 75 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                maxTargetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                targetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                minFullUtilizationRate: MIN_FULL_UTIL_RATE,
                maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
                zeroUtilizationRate: ZERO_UTIL_RATE,
                rateHalfLife: 172800,
                targetRatePercent: 0.2e18
            })
        );
    }

    function test_version_name() external view {
        assertEq(rate.version(), 1);
        assertEq(rate.name(), "Dahlia Variable Interest Rate");
    }

    function test_VariableIrm_zeroUtilization() public returns (uint256 deltaTime) {
        deltaTime = bound(deltaTime, 1, TestConstants.MAX_PERIOD_IN_SECONDS);
        delete rates;
        rates.push(NewRateSet({d: deltaTime, u: 0, i: 0, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: deltaTime, u: 0, i: 1000, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: deltaTime, u: 0, i: 2000, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: deltaTime, u: 0, i: 1582470465, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: deltaTime, u: 0, i: 1582470466, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: 265 days, u: 0, i: MAX_FULL_UTIL_RATE, newRPS: ZERO_UTIL_RATE, newUtl: 23707422621}));
        rates.push(NewRateSet({d: 365 days, u: 0, i: MAX_FULL_UTIL_RATE, newRPS: ZERO_UTIL_RATE, newUtl: 17247634441}));
        processRateTest(validator_getNewRate);
    }

    /// deltaTime does not matter if utilization is zero and deltaTime = 0
    function test_VariableIrm_zeroDeltaTimeZeroUtilization() public {
        delete rates;
        rates.push(NewRateSet({d: 0, u: 0, i: 0, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: 0, u: 0, i: 1000, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: 0, u: 0, i: 2000, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: 0, u: 0, i: 1582470465, newRPS: ZERO_UTIL_RATE, newUtl: 1582470465}));
        rates.push(NewRateSet({d: 0, u: 0, i: 1582470466, newRPS: ZERO_UTIL_RATE, newUtl: 1582470466}));
        rates.push(NewRateSet({d: 0, u: 0, i: 15824704661, newRPS: ZERO_UTIL_RATE, newUtl: 15824704661}));
        processRateTest(validator_getNewRate);
    }

    function validator_getNewRate(NewRateSet memory s, string memory index) internal view {
        (uint256 _newRatePerSec, uint256 _newFullUtilizationInterest) = rate.getNewRate(s.d, s.u, s.i);
        assertEq(_newRatePerSec, s.newRPS, index);
        assertEq(_newFullUtilizationInterest, s.newUtl, index);
    }

    function test_VariableIrm_getNewRateRandom() public {
        delete rates;
        rates.push(NewRateSet({d: 0, u: 0, i: 0, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        rates.push(NewRateSet({d: 1000, u: 0, i: 0, newRPS: ZERO_UTIL_RATE, newUtl: MIN_FULL_UTIL_RATE}));
        processRateTest(validaator_getNewRateRandom);
    }

    function validaator_getNewRateRandom(NewRateSet memory s, string memory index) internal view {
        (uint256 _newRatePerSec, uint256 _newFullUtilizationInterest) = rate.getNewRate(s.d, s.u, s.i);
        assertEq(_newRatePerSec, s.newRPS, index);
        assertEq(_newFullUtilizationInterest, s.newUtl, index);
    }

    function test_VariableIrm_calculateInterest_01() external {
        delete interests;

        interests.push(
            InterestSet({
                deltaTime: 0,
                totalLendAssets: 10e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: 0,
                expectedInterestEarnedAssets: 0,
                expectedRatePerSec: 325802741,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 1000,
                totalLendAssets: 10e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: 0,
                expectedInterestEarnedAssets: 1629013705000,
                expectedRatePerSec: 325802741,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 1000,
                totalLendAssets: 10e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: MIN_FULL_UTIL_RATE,
                expectedInterestEarnedAssets: 1629013705000,
                expectedRatePerSec: 325802741,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        processInterestTest(validator_VariableIrm_calculateInterest);
    }

    function test_VariableIrm_calculateInterest_02() external {
        delete interests;

        interests.push(
            InterestSet({
                deltaTime: 0,
                totalLendAssets: 6e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: 0,
                expectedInterestEarnedAssets: 0,
                expectedRatePerSec: 437505421,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 1000,
                totalLendAssets: 6e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: 0,
                expectedInterestEarnedAssets: 2187527105000,
                expectedRatePerSec: 437505421,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 1000,
                totalLendAssets: 5.1e18,
                totalBorrowAssets: 5e18,
                oldFullUtilizationInterest: 0,
                expectedInterestEarnedAssets: 7167578400000,
                expectedRatePerSec: 1433515680,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        processInterestTest(validator_VariableIrm_calculateInterest);
    }

    function test_VariableIrm_calculateInterest_03() external {
        delete interests;

        interests.push(
            InterestSet({
                deltaTime: 1 days,
                totalLendAssets: 10000,
                totalBorrowAssets: 500,
                oldFullUtilizationInterest: MIN_FULL_UTIL_RATE,
                expectedInterestEarnedAssets: 0,
                expectedRatePerSec: 175002615,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 365 days,
                totalLendAssets: 10000,
                totalBorrowAssets: 3000,
                oldFullUtilizationInterest: MIN_FULL_UTIL_RATE,
                expectedInterestEarnedAssets: 24,
                expectedRatePerSec: 258780463,
                expectedFullUtilizationInterest: MIN_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 365 days,
                totalLendAssets: 10000,
                totalBorrowAssets: 9000,
                oldFullUtilizationInterest: MIN_FULL_UTIL_RATE,
                expectedInterestEarnedAssets: 4483,
                expectedRatePerSec: 15797743991,
                expectedFullUtilizationInterest: 33671454787
            })
        );
        interests.push(
            InterestSet({
                deltaTime: 30 days,
                totalLendAssets: 10000,
                totalBorrowAssets: 10000,
                oldFullUtilizationInterest: MIN_FULL_UTIL_RATE,
                expectedInterestEarnedAssets: 656,
                expectedRatePerSec: 25319527360,
                expectedFullUtilizationInterest: 25319527360
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 365 days,
                totalLendAssets: 10000,
                totalBorrowAssets: 10000,
                oldFullUtilizationInterest: 290383329410,
                expectedInterestEarnedAssets: 998095,
                expectedRatePerSec: MAX_FULL_UTIL_RATE,
                expectedFullUtilizationInterest: MAX_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 365 days,
                totalLendAssets: 1 ether,
                totalBorrowAssets: 1 ether,
                oldFullUtilizationInterest: 290383329410,
                expectedInterestEarnedAssets: 99809576853120000000,
                expectedRatePerSec: MAX_FULL_UTIL_RATE,
                expectedFullUtilizationInterest: MAX_FULL_UTIL_RATE
            })
        );

        interests.push(
            InterestSet({
                deltaTime: 365 days,
                totalLendAssets: 1_000_000_000_000 ether,
                totalBorrowAssets: 1_000_000_000_000 ether,
                oldFullUtilizationInterest: 290383329410,
                expectedInterestEarnedAssets: 99809576853120000000000000000000,
                expectedRatePerSec: MAX_FULL_UTIL_RATE,
                expectedFullUtilizationInterest: MAX_FULL_UTIL_RATE
            })
        );

        processInterestTest(validator_VariableIrm_calculateInterest);
    }

    function validator_VariableIrm_calculateInterest(InterestSet memory s, string memory index) internal view {
        (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
            rate.calculateInterest(s.deltaTime, s.totalLendAssets, s.totalBorrowAssets, s.oldFullUtilizationInterest);
        assertEq(
            newFullUtilizationRate,
            s.expectedFullUtilizationInterest,
            string.concat(index, ": expectedFullUtilizationInterest")
        );
        assertEq(newRatePerSec, s.expectedRatePerSec, string.concat(index, ": expectedRatePerSec"));
        assertEq(
            interestEarnedAssets, s.expectedInterestEarnedAssets, string.concat(index, ": expectedInterestEarnedAssets")
        );
    }
}
