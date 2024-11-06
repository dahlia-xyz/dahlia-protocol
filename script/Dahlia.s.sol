// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "@forge-std/Script.sol";
import {console} from "@forge-std/console.sol";
import {Dahlia} from "src/core/contracts/Dahlia.sol";
import {DahliaRegistry} from "src/core/contracts/DahliaRegistry.sol";

contract DeployDahlia is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // Use environment variable for security
        vm.startBroadcast(deployerPrivateKey);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployerAddress);

        address registry = address(new DahliaRegistry(dahliaOwner));
        // Deploy the contract
        Dahlia dahlia = new Dahlia(dahliaOwner, registry);
        console.log("Dahlia contract deployed to:", address(dahlia));
        uint256 contractSize = address(dahlia).code.length;
        console.log("Dahlia contract size:", contractSize);

        vm.stopBroadcast();
    }
}
