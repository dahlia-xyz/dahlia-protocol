// SPDX-License-Identifier: ISC
pragma solidity ^0.8.27;

import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

contract IrmFactory {
    event VariableIrmCreated(address indexed irmAddressm, VariableIrm.Config config);

    error IncorrectConfig();

    function createVariableIrm(VariableIrm.Config memory config) external returns (IIrm) {
        require(config.maxTargetUtilization < IrmConstants.UTILIZATION_100_PERCENT, IncorrectConfig());
        require(config.minTargetUtilization < config.maxTargetUtilization, IncorrectConfig());
        VariableIrm irm = new VariableIrm(config);
        emit VariableIrmCreated(address(irm), config);
        return irm;
    }
}
