// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

contract WrappedVaultImplementationScript is BaseScript {
    string public constant WRAPPED_VAULT_SALT = "WrappedVault_V1";

    function run() public {
        vm.startBroadcast(deployer);
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_SALT));
        bytes memory initCode = type(WrappedVault).creationCode;
        string memory name = type(WrappedVault).name;
        deploy(name, DEPLOYED_WRAPPED_VAULT_IMPLEMENTATION, salt, initCode);
        vm.stopBroadcast();
    }
}
