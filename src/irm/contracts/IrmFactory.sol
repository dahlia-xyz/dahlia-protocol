// SPDX-License-Identifier: ISC
pragma solidity ^0.8.27;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

contract IrmFactory {
    event VariableIrmCreated(address indexed irmAddress, VariableIrm.Config config);

    error IncorrectConfig();

    uint256 internal constant CONFIG_PARAMS_BYTES_LENGTH = 8 * 32;

    /// @dev returns the hash of the init code (creation code + ABI-encoded args) used in CREATE2
    /// @param creationCode the creation code of a contract C, as returned by type(C).creationCode
    /// @param args the ABI-encoded arguments to the constructor of C
    function hashInitCode(bytes memory creationCode, bytes memory args) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(creationCode, args));
    }

    function createVariableIrm(VariableIrm.Config memory config) external returns (IIrm) {
        bytes32 salt;
        assembly ("memory-safe") {
            salt := keccak256(config, CONFIG_PARAMS_BYTES_LENGTH)
        }
        require(config.maxTargetUtilization < IrmConstants.UTILIZATION_100_PERCENT, IncorrectConfig());
        require(config.minTargetUtilization < config.maxTargetUtilization, IncorrectConfig());
        require(config.minFullUtilizationRate <= config.maxFullUtilizationRate, IncorrectConfig());
        VariableIrm irm;
        bytes memory encodedArgs = abi.encode(
            config.minTargetUtilization,
            config.maxTargetUtilization,
            config.targetUtilization,
            config.rateHalfLife,
            config.minFullUtilizationRate,
            config.maxFullUtilizationRate,
            config.zeroUtilizationRate,
            config.targetRatePercent
        );
        bytes32 initCodeHash = hashInitCode(type(VariableIrm).creationCode, encodedArgs);
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            irm = VariableIrm(expectedAddress);
        } else {
            irm = new VariableIrm{ salt: salt }(config);
            address irmAddress = address(irm);
            require(expectedAddress == irmAddress);
        }
        emit VariableIrmCreated(address(irm), config);
        return irm;
    }
}
