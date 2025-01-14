// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";

contract IrmFactoryScript is BaseScript {
    string public constant IRM_FACTORY_SALT = "IrmFactory_V1";

    function run() public {
        vm.startBroadcast(deployer);
        bytes32 salt = keccak256(abi.encode(IRM_FACTORY_SALT));
        address factory = CREATE3.predictDeterministicAddress(salt);
        if (factory.code.length > 0) {
            console.log("IrmFactory already deployed:");
        } else {
            bytes memory initCode = type(IrmFactory).creationCode;
            factory = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract("IRM_FACTORY", factory);
        vm.stopBroadcast();
    }
}
