// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";

contract PointsFactoryScript is BaseScript {
    string public constant POINTS_FACTORY_SALT = "PointsFactory_V1";

    function run() public {
        address pointsFactoryFromEnv = _envOr(POINTS_FACTORY, address(0));
        address dahliaOwner = _envAddress("DAHLIA_OWNER");
        string memory name = type(PointsFactory).name;
        if (pointsFactoryFromEnv == address(0)) {
            bytes32 salt = keccak256(abi.encode(POINTS_FACTORY_SALT));
            bytes memory encodedArgs = abi.encode(dahliaOwner);
            bytes memory initCode = abi.encodePacked(type(PointsFactory).creationCode, encodedArgs);
            _deploy(name, POINTS_FACTORY, salt, initCode);
        } else {
            console.log(name, "- already deployed");
        }
    }
}
