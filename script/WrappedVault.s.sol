// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";

contract DeployWrappedVault is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);

        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        vm.stopBroadcast();
    }
}
