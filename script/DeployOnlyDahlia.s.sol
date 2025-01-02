// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";

contract DeployOnlyDahlia is BaseScript {
    function _deployDahlia(address dahliaOwner, address registry) internal returns (address) {
        address dahlia = address(new Dahlia(dahliaOwner, registry));
        return dahlia;
    }

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address registry = vm.envAddress("REGISTRY");
        console.log("Deployer address:", deployer);
        // Deploy the contract
        address dahlia = _deployDahlia(dahliaOwner, registry);
        _printContract("Dahlia:                     ", dahlia);

        uint256 contractSize = dahlia.code.length;
        console.log("Dahlia contract size:", contractSize);
        vm.stopBroadcast();
    }
}
