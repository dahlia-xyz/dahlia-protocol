// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";

contract DeployDahlia is BaseScript {
    function _deployDahlia(address dahliaOwner, address registry) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner, registry);
        bytes32 initCodeHash = hashInitCode(type(Dahlia).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("Dahlia already deployed");
            return expectedAddress;
        } else {
            address dahlia = address(new Dahlia{ salt: salt }(dahliaOwner, registry));
            require(expectedAddress == dahlia);
            return dahlia;
        }
    }

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address registry = vm.envAddress("REGISTRY");
        // Deploy the contract
        address dahlia = _deployDahlia(dahliaOwner, registry);
        _printContract("DAHLIA_ADDRESS", dahlia);
        vm.stopBroadcast();
    }
}
