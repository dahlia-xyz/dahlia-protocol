// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";

contract DahliaRegistryTransferScript is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        DahliaRegistry registry = DahliaRegistry(vm.envAddress("REGISTRY"));

        address owner = registry.owner();
        if (owner == deployer) {
            // Set properly dahlia owner
            registry.transferOwnership(dahliaOwner);
        }
        vm.stopBroadcast();
    }
}
