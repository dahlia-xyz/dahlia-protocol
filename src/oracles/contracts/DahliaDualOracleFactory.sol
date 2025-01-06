// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaDualOracle } from "./DahliaDualOracle.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

contract DahliaDualOracleFactory {
    /// @notice Emitted when a new DualOracleCreated is created.
    event DahliaDualOracleCreated(address caller, IDahliaOracle indexed primary, IDahliaOracle indexed secondary);

    /// @notice Deploys a new DualOracleCreated contract.
    /// @param primary primary oracle address.
    /// @param secondary secondary oracle address.
    /// @return oracle The deployed DahliaDualOracle contract instance.
    function createDualOracle(IDahliaOracle primary, IDahliaOracle secondary) external returns (DahliaDualOracle oracle) {
        oracle = new DahliaDualOracle(primary, secondary);
        emit DahliaDualOracleCreated(msg.sender, primary, secondary);
    }
}
