// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from "../lib/forge-std/src/console.sol";
import { PointsFactory } from "../lib/royco/src/PointsFactory.sol";
import { BaseScript } from "./BaseScript.sol";

contract PointsFactoryScript is BaseScript {
    bytes32 private constant _SALT = keccak256(abi.encode("PointsFactory_V1"));

    function run() public {
        address pointsFactoryFromEnv = _envOr(POINTS_FACTORY, address(0));
        address dahliaOwner = _envAddress(DAHLIA_OWNER);
        string memory name = type(PointsFactory).name;
        if (pointsFactoryFromEnv == address(0)) {
            bytes memory encodedArgs = abi.encode(dahliaOwner);
            bytes memory initCode = abi.encodePacked(type(PointsFactory).creationCode, encodedArgs);
            _deploy(name, POINTS_FACTORY, _SALT, initCode, true);
        } else {
            console.log(name, "already deployed");
        }
    }
}
