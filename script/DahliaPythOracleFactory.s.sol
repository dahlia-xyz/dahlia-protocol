// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    string public constant DAHLIA_PYTH_ORACLE_FACTORY_SALT = "DahliaPythOracleFactory_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        address timelock = vm.envAddress(DEPLOYED_TIMELOCK);
        bytes32 salt = keccak256(abi.encode(DAHLIA_PYTH_ORACLE_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(timelock, pythStaticOracleAddress);
        bytes memory initCode = abi.encodePacked(type(DahliaPythOracleFactory).creationCode, encodedArgs);
        string memory name = type(DahliaPythOracleFactory).name;
        deploy(name, DEPLOYED_PYTH_ORACLE_FACTORY, salt, initCode);
        vm.stopBroadcast();
    }
}
