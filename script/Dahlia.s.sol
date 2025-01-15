// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";

contract DeployDahlia is BaseScript {
    string public constant DAHLIA_SALT = "Dahlia_V1";

    function run() public {
        address dahliaOwner = envAddress("DAHLIA_OWNER");
        address registry = envAddress(DEPLOYED_REGISTRY);
        bytes32 salt = keccak256(abi.encode(DAHLIA_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner, registry);
        bytes memory initCode = abi.encodePacked(type(Dahlia).creationCode, encodedArgs);
        string memory name = type(Dahlia).name;
        deploy(name, DEPLOYED_DAHLIA, salt, initCode);
    }
}
