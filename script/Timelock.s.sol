// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { Timelock } from "src/oracles/contracts/Timelock.sol";

contract DeployTimelock is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        uint256 timelockDelay = vm.envUint("TIMELOCK_DELAY");
        Timelock timelock = _deployTimelock(dahliaOwner, timelockDelay);
        _printContract("TIMELOCK", address(timelock));
        vm.stopBroadcast();
    }
}
