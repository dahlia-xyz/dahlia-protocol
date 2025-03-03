// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { CREATE3 } from "../../../lib/solady/src/utils/CREATE3.sol";
import { DahliaOracleFactoryBase } from "../abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "../abstracts/DahliaOracleStaticAddress.sol";
import { DahliaKodiakIslandPythOracle } from "./DahliaKodiakIslandPythOracle.sol";

contract DahliaKodiakIslandPythOracleFactory is DahliaOracleFactoryBase, DahliaOracleStaticAddress {
    /// @notice Emitted when a new Kodiak Island Pyth oracle is created.
    event DahliaKodiakIslandPythOracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress and pythStaticOracleAddress.
    /// @param timelock The address of the timelock.
    /// @param pythStaticOracle The address of a deployed Pyth static oracle.
    constructor(address timelock, address pythStaticOracle) DahliaOracleFactoryBase(timelock) DahliaOracleStaticAddress(pythStaticOracle) { }

    /// @notice Deploys a new DahliaKodiakIslandPythOracle contract, or return the existing one if already deployed.
    /// @param params DahliaKodiakIslandPythOracle.Params struct.
    /// @param delays DahliaKodiakIslandPythOracle.Delays struct.
    /// @return oracle The deployed (or existing) DahliaKodiakIslandPythOracle contract.
    function createKodiakIslandPythOracle(DahliaKodiakIslandPythOracle.Params memory params, DahliaKodiakIslandPythOracle.Delays memory delays)
        external
        returns (address oracle)
    {
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS);
        bytes32 salt = keccak256(encodedArgs);
        oracle = CREATE3.predictDeterministicAddress(salt);

        if (oracle.code.length == 0) {
            bytes memory initCode = abi.encodePacked(type(DahliaKodiakIslandPythOracle).creationCode, encodedArgs);
            oracle = CREATE3.deployDeterministic(0, initCode, salt);
            emit DahliaKodiakIslandPythOracleCreated(msg.sender, oracle);
        }
    }
}
