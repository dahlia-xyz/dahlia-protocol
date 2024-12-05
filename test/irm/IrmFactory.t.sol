// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";

import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";

contract IrmFactoryTest is Test {
    using BoundUtils for Vm;

    uint64 constant ZERO_UTIL_RATE = 158_247_046;
    uint64 constant MIN_FULL_UTIL_RATE = 1_582_470_460;
    uint64 constant MAX_FULL_UTIL_RATE = 3_164_940_920_000;

    uint256 ORACLE_PRECISION = 1e18;
    TestContext ctx;
    IrmFactory irmFactory;
    VariableIrm.Config defaultConfig;

    function setUp() public {
        ctx = new TestContext(vm);
        irmFactory = new IrmFactory();

        defaultConfig = VariableIrm.Config({
            minTargetUtilization: 75 * IrmConstants.UTILIZATION_100_PERCENT / 100,
            maxTargetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
            targetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
            minFullUtilizationRate: MIN_FULL_UTIL_RATE,
            maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
            zeroUtilizationRate: ZERO_UTIL_RATE,
            rateHalfLife: 172_800,
            targetRatePercent: 0.2e18
        });
    }

    function test_irmFactory_variableIrm_success() public {
        VariableIrm irm = VariableIrm(address(irmFactory.createVariableIrm(defaultConfig)));
        assertEq(irm.minFullUtilizationRate(), defaultConfig.minFullUtilizationRate);
        assertEq(irm.zeroUtilizationRate(), defaultConfig.zeroUtilizationRate);
        assertEq(irm.maxFullUtilizationRate(), defaultConfig.maxFullUtilizationRate);
        assertEq(irm.targetRatePercent(), defaultConfig.targetRatePercent);
        assertEq(irm.rateHalfLife(), defaultConfig.rateHalfLife);
        assertEq(irm.targetUtilization(), defaultConfig.targetUtilization);
        assertEq(irm.minTargetUtilization(), defaultConfig.minTargetUtilization);
        assertEq(irm.maxTargetUtilization(), defaultConfig.maxTargetUtilization);
    }

    function test_irmFactory_variableIrm_reverts() public {
        // check minTargetUtilization overflow
        defaultConfig.maxTargetUtilization = IrmConstants.UTILIZATION_100_PERCENT + 1;
        vm.expectRevert(IrmFactory.IncorrectConfig.selector);
        irmFactory.createVariableIrm(defaultConfig);

        // check minTargetUtilization > maxTargetUtilization
        defaultConfig.minTargetUtilization = 76 * IrmConstants.UTILIZATION_100_PERCENT / 100;
        defaultConfig.maxTargetUtilization = 75 * IrmConstants.UTILIZATION_100_PERCENT / 100;
        vm.expectRevert(IrmFactory.IncorrectConfig.selector);
        irmFactory.createVariableIrm(defaultConfig);

        // check maxFullUtilizationRate > maxFullUtilizationRate
        defaultConfig.minTargetUtilization = 70 * IrmConstants.UTILIZATION_100_PERCENT / 100;
        defaultConfig.maxTargetUtilization = 75 * IrmConstants.UTILIZATION_100_PERCENT / 100;
        defaultConfig.minFullUtilizationRate = MAX_FULL_UTIL_RATE;
        defaultConfig.maxFullUtilizationRate = MIN_FULL_UTIL_RATE;
        vm.expectRevert(IrmFactory.IncorrectConfig.selector);
        irmFactory.createVariableIrm(defaultConfig);
    }
}
