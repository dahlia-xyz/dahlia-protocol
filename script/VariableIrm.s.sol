// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

contract VariableIrmScript is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        IrmFactory irmFactory = IrmFactory(envAddress(DEPLOYED_IRM_FACTORY));
        uint256 ZERO_UTIL_RATE = envUint("ZERO_UTIL_RATE");
        uint256 MIN_FULL_UTIL_RATE = envUint("MIN_FULL_UTIL_RATE");
        uint256 MAX_FULL_UTIL_RATE = envUint("MAX_FULL_UTIL_RATE");
        uint256 MIN_TARGET_UTILIZATION = envUint("MIN_TARGET_UTILIZATION");
        uint256 MAX_TARGET_UTILIZATION = envUint("MAX_TARGET_UTILIZATION");
        uint256 TARGET_UTILIZATION = envUint("TARGET_UTILIZATION");
        uint256 RATE_HALF_LIFE = envUint("RATE_HALF_LIFE");
        uint256 TARGET_RATE_PERCENT = envUint("TARGET_RATE_PERCENT");
        string memory name = envString("IRM_NAME");
        string memory INDEX = envString("INDEX");

        IIrm irm = irmFactory.createVariableIrm(
            VariableIrm.Config({
                minTargetUtilization: MIN_TARGET_UTILIZATION,
                maxTargetUtilization: MAX_TARGET_UTILIZATION,
                targetUtilization: TARGET_UTILIZATION,
                minFullUtilizationRate: MIN_FULL_UTIL_RATE,
                maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
                zeroUtilizationRate: ZERO_UTIL_RATE,
                rateHalfLife: RATE_HALF_LIFE,
                targetRatePercent: TARGET_RATE_PERCENT,
                name: name
            })
        );

        string memory contractName = string(abi.encodePacked("DEPLOYED_IRM_", INDEX));
        _printContract(contractName, address(irm));
        vm.stopBroadcast();
    }
}
