// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";

contract WrappedVaultFactoryScript is BaseScript {
    string public constant WRAPPED_VAULT_FACTORY_SALT = "WrappedVaultFactory_V1";

    function run() public {
        address dahliaOwner = _envAddress("DAHLIA_OWNER");
        address feesRecipient = _envAddress("FEES_RECIPIENT");
        address pointsFactory = _envAddress(POINTS_FACTORY);
        address wrappedVaultImplementation = _envAddress(DEPLOYED_WRAPPED_VAULT_IMPLEMENTATION);
        address dahlia = _envAddress(DEPLOYED_DAHLIA);
        uint256 protocolFee = _envUint("WRAPPED_VAULT_FACTORY_PROTOCOL_FEE");
        uint256 minimumFrontendFee = _envUint("WRAPPED_VAULT_FACTORY_MIN_FRONTEND_FEE");

        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(wrappedVaultImplementation, feesRecipient, protocolFee, minimumFrontendFee, dahliaOwner, pointsFactory, dahlia);
        bytes memory initCode = abi.encodePacked(type(WrappedVaultFactory).creationCode, encodedArgs);
        string memory name = type(WrappedVaultFactory).name;
        _deploy(name, DEPLOYED_WRAPPED_VAULT_FACTORY, salt, initCode);
    }
}
