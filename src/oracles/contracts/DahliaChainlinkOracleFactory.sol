// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaChainlinkOracle } from "./DahliaChainlinkOracle.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
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
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, maxDelays);
        bytes32 salt = keccak256(encodedArgs);
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(DahliaChainlinkOracle).creationCode, encodedArgs));
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);

        if (expectedAddress.code.length > 0) {
            oracle = DahliaChainlinkOracle(expectedAddress);
        } else {
            oracle = new DahliaChainlinkOracle{ salt: salt }(_TIMELOCK, params, maxDelays);
            emit DahliaChainlinkOracleCreated(msg.sender, address(oracle));
        }
    }
}
