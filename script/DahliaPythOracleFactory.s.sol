// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    function _deployDahliaPythOracleFactory(address timelockAddress, address pythStaticOracleAddress) internal returns (address factory) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_PYTH_ORACLE_FACTORY_SALT));
        factory = CREATE3.predictDeterministicAddress(salt);
        if (factory.code.length > 0) {
            console.log("DahliaOracleFactory already deployed");
        } else {
            bytes memory encodedArgs = abi.encode(timelockAddress, pythStaticOracleAddress);
            bytes memory initCode = abi.encodePacked(type(DahliaPythOracleFactory).creationCode, encodedArgs);
            factory = CREATE3.deployDeterministic(initCode, salt);
        }
    }

    function run() public {
        vm.startBroadcast(deployer);
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK");
        address oracleFactory = _deployDahliaPythOracleFactory(timelockAddress, pythStaticOracleAddress);
        _printContract("PYTH_ORACLE_FACTORY", oracleFactory);
        vm.stopBroadcast();
    }
}
