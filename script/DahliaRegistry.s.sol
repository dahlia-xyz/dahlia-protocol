// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";

import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";

contract DahliaRegistryScript is BaseScript {
    string public constant DAHLIA_REGISTRY_SALT = "DahliaRegistry_V1";

    function run() public {
        vm.startBroadcast(deployer);
        bytes32 salt = keccak256(abi.encode(DAHLIA_REGISTRY_SALT));
        address factory = CREATE3.predictDeterministicAddress(salt);
        if (factory.code.length > 0) {
            console.log("DahliaRegistry already deployed");
        } else {
            bytes memory encodedArgs = abi.encode(deployer); // this is not a mistake we deploy registry to be able set values
            bytes memory initCode = abi.encodePacked(type(DahliaRegistry).creationCode, encodedArgs);
            factory = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract(REGISTRY, factory);
        vm.stopBroadcast();
    }
}
