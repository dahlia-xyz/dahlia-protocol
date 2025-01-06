// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaPythOracle } from "./DahliaPythOracle.sol";
import { DahliaOracleFactoryBase } from "src/oracles/abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "src/oracles/abstracts/DahliaOracleStaticAddress.sol";

contract DahliaPythOracleFactory is DahliaOracleFactoryBase, DahliaOracleStaticAddress {
    /// @notice Emitted when a new Pyth oracle is created.
    event DahliaPythOracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress and pythStaticOracleAddress.
    /// @param timelock The address of the timelock.
    /// @param pythStaticOracle The address of a deployed Pyth static oracle.
    constructor(address timelock, address pythStaticOracle) DahliaOracleFactoryBase(timelock) DahliaOracleStaticAddress(pythStaticOracle) { }

    /// @notice Deploys a new DahliaPythOracle contract.
    /// @param params DahliaPythOracle.Params struct.
    /// @param delays DahliaPythOracle.Delays struct.
    /// @return oracle The deployed DahliaPythOracle contract instance.
    function createPythOracle(DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays) external returns (DahliaPythOracle oracle) {
        oracle = new DahliaPythOracle(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS);
        emit DahliaPythOracleCreated(msg.sender, address(oracle));
    }
}
