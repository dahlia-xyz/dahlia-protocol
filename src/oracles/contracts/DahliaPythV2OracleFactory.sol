// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { CREATE3 } from "../../../lib/solady/src/utils/CREATE3.sol";
import { DahliaOracleFactoryBase } from "../abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "../abstracts/DahliaOracleStaticAddress.sol";
import { DahliaPythV2Oracle } from "./DahliaPythV2Oracle.sol";

contract DahliaPythV2OracleFactory is DahliaOracleFactoryBase, DahliaOracleStaticAddress {
    /// @notice Emitted when a new Pyth oracle is created.
    event DahliaPythV2OracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress and pythStaticOracleAddress.
    /// @param timelock The address of the timelock.
    /// @param pythStaticOracle The address of a deployed Pyth static oracle.
    constructor(address timelock, address pythStaticOracle) DahliaOracleFactoryBase(timelock) DahliaOracleStaticAddress(pythStaticOracle) { }

    /// @notice Deploys a new DahliaPythV2Oracle contract, or return the existing one if already deployed.
    /// @param params DahliaPythV2Oracle.Params struct.
    /// @param delays DahliaPythV2Oracle.Delays struct.
    /// @return oracle The deployed (or existing) DahliaPythV2Oracle contract.
    function createPythV2Oracle(DahliaPythV2Oracle.Params memory params, DahliaPythV2Oracle.Delays memory delays) external returns (address oracle) {
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS);
        bytes32 salt = keccak256(encodedArgs);
        oracle = CREATE3.predictDeterministicAddress(salt);

        if (oracle.code.length == 0) {
            bytes memory initCode = abi.encodePacked(type(DahliaPythV2Oracle).creationCode, encodedArgs);
            oracle = CREATE3.deployDeterministic(0, initCode, salt);
            emit DahliaPythV2OracleCreated(msg.sender, oracle);
        }
    }
}
