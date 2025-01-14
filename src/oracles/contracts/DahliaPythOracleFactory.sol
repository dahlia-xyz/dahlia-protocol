// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaPythOracle } from "./DahliaPythOracle.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
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
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS);
        bytes32 salt = keccak256(encodedArgs);
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(DahliaPythOracle).creationCode, encodedArgs));
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);

        if (expectedAddress.code.length > 0) {
            oracle = DahliaPythOracle(expectedAddress);
        } else {
            oracle = new DahliaPythOracle{ salt: salt }(_TIMELOCK, params, delays, _STATIC_ORACLE_ADDRESS);
            emit DahliaPythOracleCreated(msg.sender, address(oracle));
        }
    }
}
