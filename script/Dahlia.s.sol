// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";

contract DeployDahlia is BaseScript {
    string public constant DAHLIA_SALT = "Dahlia_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address registry = vm.envAddress(DEPLOYED_REGISTRY);
        bytes32 salt = keccak256(abi.encode(DAHLIA_SALT));
        address dahlia = CREATE3.predictDeterministicAddress(salt);
        if (dahlia.code.length > 0) {
            console.log("Dahlia already deployed");
        } else {
            bytes memory encodedArgs = abi.encode(dahliaOwner, registry);
            bytes memory initCode = abi.encodePacked(type(Dahlia).creationCode, encodedArgs);
            dahlia = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract(DEPLOYED_DAHLIA, dahlia);
        vm.stopBroadcast();
    }
}
