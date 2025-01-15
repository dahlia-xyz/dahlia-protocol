// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";

contract VariableIrmScript is BaseScript {
    function run() public {
        IrmFactory irmFactory = IrmFactory(_envAddress(DEPLOYED_IRM_FACTORY));
        uint256 ZERO_UTIL_RATE = _envUint("ZERO_UTIL_RATE");
        uint256 MIN_FULL_UTIL_RATE = _envUint("MIN_FULL_UTIL_RATE");
        uint256 MAX_FULL_UTIL_RATE = _envUint("MAX_FULL_UTIL_RATE");
        uint256 MIN_TARGET_UTILIZATION = _envUint("MIN_TARGET_UTILIZATION");
        uint256 MAX_TARGET_UTILIZATION = _envUint("MAX_TARGET_UTILIZATION");
        uint256 TARGET_UTILIZATION = _envUint("TARGET_UTILIZATION");
        uint256 RATE_HALF_LIFE = _envUint("RATE_HALF_LIFE");
        uint256 TARGET_RATE_PERCENT = _envUint("TARGET_RATE_PERCENT");
        string memory name = _envString("IRM_NAME");
        string memory INDEX = _envString("INDEX");

        VariableIrm.Config memory config = VariableIrm.Config({
            minTargetUtilization: MIN_TARGET_UTILIZATION,
            maxTargetUtilization: MAX_TARGET_UTILIZATION,
            targetUtilization: TARGET_UTILIZATION,
            minFullUtilizationRate: MIN_FULL_UTIL_RATE,
            maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
            zeroUtilizationRate: ZERO_UTIL_RATE,
            rateHalfLife: RATE_HALF_LIFE,
            targetRatePercent: TARGET_RATE_PERCENT,
            name: name
        });
        bytes memory encodedArgs = abi.encode(config);
        bytes32 salt = keccak256(encodedArgs);
        address irm = CREATE3.predictDeterministicAddress(salt, address(irmFactory));
        string memory contractName = string(abi.encodePacked("DEPLOYED_IRM_", INDEX));
        if (irm.code.length == 0) {
            vm.startBroadcast(deployer);
            irm = irmFactory.createVariableIrm(config);
            _printContract(contractName, irm);
            vm.stopBroadcast();
        } else {
            console.log(contractName, "already deployed");
        }
    }
}
