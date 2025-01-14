// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript, Deploy } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { TestConstants } from "test/common/TestConstants.sol";

contract WrappedVaultFactoryScript is BaseScript {
    string public constant WRAPPED_VAULT_FACTORY_SALT = "WrappedVaultFactory_V1";

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        address pointsFactory = vm.envAddress("POINTS_FACTORY");
        address wrappedVaultImplementation = vm.envAddress("WRAPPED_VAULT_IMPLEMENTATION");
        address dahlia = vm.envAddress(Deploy.DAHLIA_ADDRESS);
        address registry = vm.envAddress("REGISTRY");
        uint256 protocolFee = TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE;
        uint256 minimumFrontendFee = TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE;

        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_FACTORY_SALT));
        address factory = CREATE3.predictDeterministicAddress(salt);
        if (factory.code.length > 0) {
            console.log("WrappedVaultFactory already deployed");
        } else {
            bytes memory encodedArgs =
                abi.encode(wrappedVaultImplementation, feesRecipient, protocolFee, minimumFrontendFee, dahliaOwner, pointsFactory, dahlia);
            bytes memory initCode = abi.encodePacked(type(WrappedVaultFactory).creationCode, encodedArgs);
            factory = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract("WRAPPED_VAULT_FACTORY", factory);
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        address owner = DahliaRegistry(registry).owner();
        console.log("Dahlia Registry owner:", owner);
        DahliaRegistry(registry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, factory);
        vm.stopBroadcast();
    }
}
