// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaChainlinkOracle } from "./DahliaChainlinkOracle.sol";
import { DahliaOracleFactoryBase } from "src/oracles/abstracts/DahliaOracleFactoryBase.sol";

/// @title DahliaChainlinkOracleFactory factory to create chainlink oracle
contract DahliaChainlinkOracleFactory is DahliaOracleFactoryBase {
    /// @notice Emitted when a new Chainlink oracle is created.
    event DahliaChainlinkOracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress.
    /// @param timelock The address of the timelock.
    constructor(address timelock) DahliaOracleFactoryBase(timelock) { }

    /// @notice Creates a new Chainlink oracle contract.
    /// @param params Chainlink oracle parameters.
    /// @param maxDelays Chainlink maximum delay parameters.
    /// @return oracle The deployed DahliaChainlinkOracle contract instance.
    function createChainlinkOracle(DahliaChainlinkOracle.Params memory params, DahliaChainlinkOracle.Delays memory maxDelays)
        external
        returns (DahliaChainlinkOracle oracle)
    {
        oracle = new DahliaChainlinkOracle(_TIMELOCK, params, maxDelays);
        emit DahliaChainlinkOracleCreated(msg.sender, address(oracle));
    }
}
