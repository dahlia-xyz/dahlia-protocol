// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { Timelock } from "src/oracles/contracts/Timelock.sol";

contract TimelockScript is BaseScript {
    string public constant TIMELOCK_SALT = "Timelock_V1";

    function run() public {
        address dahliaOwner = envAddress("DAHLIA_OWNER");
        uint256 timelockDelay = envUint("TIMELOCK_DELAY");
        bytes32 salt = keccak256(abi.encode(TIMELOCK_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner, timelockDelay);
        bytes memory initCode = abi.encodePacked(type(Timelock).creationCode, encodedArgs);
        string memory name = type(Timelock).name;
        deploy(name, DEPLOYED_TIMELOCK, salt, initCode);
    }
}
