// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

contract WrappedVaultImplementationScript is BaseScript {
    string public constant WRAPPED_VAULT_SALT = "WrappedVault_V1";

    function run() public {
        vm.startBroadcast(deployer);
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_SALT));
        address vault = CREATE3.predictDeterministicAddress(salt);
        if (vault.code.length > 0) {
            console.log("WrappedVaultImplementation already deployed");
        } else {
            bytes memory initCode = type(WrappedVault).creationCode;
            vault = CREATE3.deployDeterministic(initCode, salt);
        }
        _printContract("WRAPPED_VAULT_IMPLEMENTATION", vault);
        vm.stopBroadcast();
    }
}
