// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";

contract PointsFactoryScript is BaseScript {
    string public constant POINTS_FACTORY_SALT = "PointsFactory_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address pointsFactoryFromEnv = vm.envOr(POINTS_FACTORY, address(0));
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        if (pointsFactoryFromEnv != address(0) && pointsFactoryFromEnv.code.length > 0) {
            console.log("PointsFactory already deployed");
        } else {
            bytes32 salt = keccak256(abi.encode(POINTS_FACTORY_SALT));
            address factory = CREATE3.predictDeterministicAddress(salt);
            if (factory.code.length > 0) {
                console.log("PointsFactory already deployed");
            } else {
                bytes memory encodedArgs = abi.encode(dahliaOwner);
                bytes memory initCode = abi.encodePacked(type(PointsFactory).creationCode, encodedArgs);
                factory = CREATE3.deployDeterministic(initCode, salt);
            }
            _printContract(POINTS_FACTORY, factory);
        }
        vm.stopBroadcast();
    }
}
