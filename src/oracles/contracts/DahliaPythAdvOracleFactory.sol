// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { CREATE3 } from "../../../lib/solady/src/utils/CREATE3.sol";
import { DahliaOracleFactoryBase } from "../abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "../abstracts/DahliaOracleStaticAddress.sol";
import { DahliaPythAdvOracle } from "./DahliaPythAdvOracle.sol";
import { DahliaPythOracle } from "./DahliaPythOracle.sol";

contract DahliaPythAdvOracleFactory is DahliaOracleFactoryBase, DahliaOracleStaticAddress {
    /// @notice Emitted when a new Pyth oracle is created.
    event DahliaPythOracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress and pythStaticOracleAddress.
    /// @param timelock The address of the timelock.
    /// @param pythStaticOracle The address of a deployed Pyth static oracle.
    constructor(address timelock, address pythStaticOracle) DahliaOracleFactoryBase(timelock) DahliaOracleStaticAddress(pythStaticOracle) { }

    /// @notice Deploys a new DahliaPythAdvOracle contract, or return the existing one if already deployed.
    /// @param params DahliaPythOracle.Params struct.
    /// @param delays DahliaPythOracle.Delays struct.
    /// @param baseTokenDecimals The decimal places of the base token that is not available yet.
    /// @param baseFeedExpo The expo of the base feed that is not available yet.
    /// @return oracle The deployed (or existing) DahliaPythOracle contract.
    function createPythAdvOracle(DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays, int256 baseTokenDecimals, int256 baseFeedExpo)
        external
        returns (address oracle)
    {
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS, baseTokenDecimals, baseFeedExpo);
        bytes32 salt = keccak256(encodedArgs);
        oracle = CREATE3.predictDeterministicAddress(salt);

        if (oracle.code.length == 0) {
            bytes memory initCode = abi.encodePacked(type(DahliaPythAdvOracle).creationCode, encodedArgs);
            oracle = CREATE3.deployDeterministic(0, initCode, salt);
            emit DahliaPythOracleCreated(msg.sender, oracle);
        }
    }
}
