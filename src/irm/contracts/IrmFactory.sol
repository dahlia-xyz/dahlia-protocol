// SPDX-License-Identifier: ISC
pragma solidity ^0.8.27;

import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

contract IrmFactory {
    event VariableIrmCreated(address indexed irmAddress, VariableIrm.Config config);

    error IncorrectConfig();

    uint256 internal constant CONFIG_PARAMS_BYTES_LENGTH = 8 * 32;

    function createVariableIrm(VariableIrm.Config memory config) external returns (IIrm) {
        bytes32 salt;
        assembly ("memory-safe") {
            salt := keccak256(config, CONFIG_PARAMS_BYTES_LENGTH)
        }
        require(config.maxTargetUtilization < IrmConstants.UTILIZATION_100_PERCENT, IncorrectConfig());
        require(config.minTargetUtilization < config.maxTargetUtilization, IncorrectConfig());
        require(config.minFullUtilizationRate <= config.maxFullUtilizationRate, IncorrectConfig());
        VariableIrm irm = new VariableIrm{ salt: salt }(config);
        emit VariableIrmCreated(address(irm), config);
        return irm;
    }
}
