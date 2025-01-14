// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";

import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";

contract DahliaRegistryScript is BaseScript {
    string public constant DAHLIA_REGISTRY_SALT = "DahliaRegistry_V1";

    function _deployDahliaRegistry(address dahliaOwner) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_REGISTRY_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner);
        bytes32 initCodeHash = hashInitCode(type(DahliaRegistry).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("DahliaRegistry already deployed");
            return expectedAddress;
        } else {
            address registry = address(new DahliaRegistry{ salt: salt }(dahliaOwner));
            require(expectedAddress == registry);
            return registry;
        }
    }

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        bytes32 salt = keccak256(abi.encode(DAHLIA_REGISTRY_SALT));
        address factory = CREATE3.predictDeterministicAddress(salt);
        if (factory.code.length > 0) {
            console.log("DahliaRegistry already deployed");
        } else {
            bytes memory encodedArgs = abi.encode(dahliaOwner);
            bytes memory initCode = abi.encodePacked(type(DahliaRegistry).creationCode, encodedArgs);
            factory = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract("REGISTRY", factory);
        vm.stopBroadcast();
    }
}
