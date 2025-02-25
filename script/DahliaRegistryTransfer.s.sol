// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from "../lib/forge-std/src/console.sol";
import { DahliaRegistry } from "../src/core/contracts/DahliaRegistry.sol";
import { BaseScript } from "./BaseScript.sol";

contract DahliaRegistryTransferScript is BaseScript {
    function run() public {
        address dahliaOwner = _envAddress(DAHLIA_OWNER);
        DahliaRegistry registry = DahliaRegistry(_envAddress(DEPLOYED_REGISTRY));

        address owner = registry.owner();
        console.log("Registry owner:", owner);
        if (owner == deployer && deployer != dahliaOwner) {
            vm.startBroadcast(deployer);
            // Set properly dahlia owner
            registry.transferOwnership(dahliaOwner);
            vm.stopBroadcast();
        }
    }
}
