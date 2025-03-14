// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaPythV2OracleFactory } from "../src/oracles/contracts/DahliaPythV2OracleFactory.sol";
import { BaseScript } from "./BaseScript.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    bytes32 private constant _SALT = keccak256(abi.encode("DahliaPythV2OracleFactory_V1"));

    function run() public {
        address pythStaticOracleAddress = _envAddress(PYTH_STATIC_ORACLE_ADDRESS);
        address timelock = _envAddress(DEPLOYED_TIMELOCK);
        bytes memory encodedArgs = abi.encode(timelock, pythStaticOracleAddress);
        bytes memory initCode = abi.encodePacked(type(DahliaPythV2OracleFactory).creationCode, encodedArgs);
        string memory name = type(DahliaPythV2OracleFactory).name;
        _deploy(name, DEPLOYED_PYTH_V2_ORACLE_FACTORY, _SALT, initCode, true);
    }
}
