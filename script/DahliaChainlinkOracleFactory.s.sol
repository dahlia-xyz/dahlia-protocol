// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaChainlinkOracleFactory } from "src/oracles/contracts/DahliaChainlinkOracleFactory.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    bytes32 private constant _SALT = keccak256(abi.encode("DahliaChainlinkOracleFactory_V1"));

    function run() public {
        address timelock = _envAddress(DEPLOYED_TIMELOCK);
        bytes memory encodedArgs = abi.encode(timelock);
        bytes memory initCode = abi.encodePacked(type(DahliaChainlinkOracleFactory).creationCode, encodedArgs);
        string memory name = type(DahliaChainlinkOracleFactory).name;
        _deploy(name, DEPLOYED_CHAINLINK_ORACLE_FACTORY, _SALT, initCode);
    }
}
