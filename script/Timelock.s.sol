// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { Timelock } from "src/oracles/contracts/Timelock.sol";

contract TimelockScript is BaseScript {
    string public constant TIMELOCK_SALT = "Timelock_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        uint256 timelockDelay = vm.envUint("TIMELOCK_DELAY");
        bytes32 salt = keccak256(abi.encode(TIMELOCK_SALT));
        address timelock = CREATE3.predictDeterministicAddress(salt);
        if (timelock.code.length > 0) {
            console.log("Timelock already deployed");
        } else {
            bytes memory encodedArgs = abi.encode(dahliaOwner, timelockDelay);
            bytes memory initCode = abi.encodePacked(type(Timelock).creationCode, encodedArgs);
            timelock = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract(TIMELOCK, timelock);
        vm.stopBroadcast();
    }
}
