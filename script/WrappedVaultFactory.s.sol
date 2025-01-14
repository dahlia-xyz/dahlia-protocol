// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";

contract WrappedVaultFactoryScript is BaseScript {
    string public constant WRAPPED_VAULT_FACTORY_SALT = "WrappedVaultFactory_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        address pointsFactory = vm.envAddress(POINTS_FACTORY);
        address wrappedVaultImplementation = vm.envAddress(DEPLOYED_WRAPPED_VAULT_IMPLEMENTATION);
        address dahlia = vm.envAddress(DEPLOYED_DAHLIA);
        DahliaRegistry registry = DahliaRegistry(vm.envAddress(DEPLOYED_REGISTRY));
        uint256 protocolFee = vm.envUint("WRAPPED_VAULT_FACTORY_PROTOCOL_FEE");
        uint256 minimumFrontendFee = vm.envUint("WRAPPED_VAULT_FACTORY_MIN_FRONTEND_FEE");

        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(wrappedVaultImplementation, feesRecipient, protocolFee, minimumFrontendFee, dahliaOwner, pointsFactory, dahlia);
        bytes memory initCode = abi.encodePacked(type(WrappedVaultFactory).creationCode, encodedArgs);
        string memory name = type(WrappedVaultFactory).name;
        address factory = deploy(name, DEPLOYED_WRAPPED_VAULT_FACTORY, salt, initCode);
        address owner = registry.owner();
        if (owner == deployer) {
            console.log("Dahlia Registry owner:", owner);
            console.log("Set ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY in registry", owner);
            registry.setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, factory);
        }
        vm.stopBroadcast();
    }
}
