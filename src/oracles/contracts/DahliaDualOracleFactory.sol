// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaDualOracle } from "./DahliaDualOracle.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { Errors } from "src/oracles/helpers/Errors.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

contract DahliaDualOracleFactory {
    /// @notice Emitted when a new DahliaDualOracle is deployed.
    /// @param caller The address that triggered the deployment.
    /// @param oracle Deployed oracle address.
    event DahliaDualOracleCreated(address indexed caller, address indexed oracle);

    /// @notice Deploy a new DahliaDualOracle using CREATE2, or return the existing one if already deployed.
    /// @param primary primary oracle address.
    /// @param secondary secondary oracle address.
    /// @return oracle The deployed (or existing) DahliaDualOracle contract.
    function createDualOracle(IDahliaOracle primary, IDahliaOracle secondary) external returns (DahliaDualOracle oracle) {
        require(address(primary) != address(0) && address(secondary) != address(0), Errors.ZeroAddress());

        bytes memory encodedArgs = abi.encode(primary, secondary);
        bytes32 salt = keccak256(encodedArgs);
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(DahliaDualOracle).creationCode, encodedArgs));
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);

        if (expectedAddress.code.length > 0) {
            oracle = DahliaDualOracle(expectedAddress);
        } else {
            oracle = new DahliaDualOracle{ salt: salt }(primary, secondary);
            emit DahliaDualOracleCreated(msg.sender, address(oracle));
        }
    }
}
