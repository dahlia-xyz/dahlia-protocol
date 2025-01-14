// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";

contract PointsFactoryScript is BaseScript {
    string public constant POINTS_FACTORY_SALT = "PointsFactory_V1";

    function run() public {
        address pointsFactoryFromEnv = vm.envOr(POINTS_FACTORY, address(0));
        if (pointsFactoryFromEnv == address(0)) {
            address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
            bytes32 salt = keccak256(abi.encode(POINTS_FACTORY_SALT));
            bytes memory encodedArgs = abi.encode(dahliaOwner);
            bytes memory initCode = abi.encodePacked(type(PointsFactory).creationCode, encodedArgs);
            string memory name = type(PointsFactory).name;
            deploy(name, POINTS_FACTORY, salt, initCode);
        }
    }
}
