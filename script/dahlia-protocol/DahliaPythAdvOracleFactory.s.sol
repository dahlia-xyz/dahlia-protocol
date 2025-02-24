// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaPythAdvOracleFactory } from "src/oracles/contracts/DahliaPythAdvOracleFactory.sol";

contract DahliaPythAdvOracleFactoryScript is BaseScript {
    bytes32 private constant _SALT = keccak256(abi.encode("DahliaPythAdvOracleFactory_V1"));

    function run() public {
        address pythStaticOracleAddress = _envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        address timelock = _envAddress(DEPLOYED_TIMELOCK);
        bytes memory encodedArgs = abi.encode(timelock, pythStaticOracleAddress);
        bytes memory initCode = abi.encodePacked(type(DahliaPythAdvOracleFactory).creationCode, encodedArgs);
        string memory name = type(DahliaPythAdvOracleFactory).name;
        _deploy(name, DEPLOYED_PYTH_ADV_ORACLE_FACTORY, _SALT, initCode, true);
    }
}
