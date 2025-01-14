// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaDualOracle } from "./DahliaDualOracle.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

contract DahliaDualOracleFactory {
    /// @notice Emitted when a new DualOracleCreated is created.
    event DahliaDualOracleCreated(address caller, IDahliaOracle indexed primary, IDahliaOracle indexed secondary);

    /// @notice Deploys a new DualOracleCreated contract.
    /// @param primary primary oracle address.
    /// @param secondary secondary oracle address.
    /// @return oracle The deployed DahliaDualOracle contract instance.
    function createDualOracle(IDahliaOracle primary, IDahliaOracle secondary) external returns (DahliaDualOracle oracle) {
        bytes memory encodedArgs = abi.encode(primary, secondary);
        bytes32 salt = keccak256(encodedArgs);
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(DahliaDualOracle).creationCode, encodedArgs));
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);

        if (expectedAddress.code.length > 0) {
            oracle = DahliaDualOracle(expectedAddress);
        } else {
            oracle = new DahliaDualOracle{ salt: salt }(primary, secondary);
            emit DahliaDualOracleCreated(msg.sender, primary, secondary);
        }
    }
}
