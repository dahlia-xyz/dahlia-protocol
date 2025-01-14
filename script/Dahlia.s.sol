// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { TestConstants } from "test/common/TestConstants.sol";

// Deploy contracts using CREATE2 contract (EVM Standard) for deterministic addresses
// Solidity CREATE2 implementation
// https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
// Foundry tutorial for self CREATE2
// https://book.getfoundry.sh/tutorials/create2-tutorial
// Foundry std function for computing CREATE2 address
// https://github.com/foundry-rs/forge-std/blob/f73c73d2018eb6a111f35e4dae7b4f27401e9421/src/StdUtils.sol#L122-L134
// Solana independent implementation
// https://github.com/Genesis3800/CREATE2Factory/blob/main/src/Create2.sol

// Kindof example https://github.com/0xsend/sendapp/blob/5fbf335a481d101d0ffd6649c2cfdc0bc1c20e16/packages/contracts/script/DeploySendAccountFactory.s.sol#L19

contract DeployDahlia is BaseScript {
    function _deployPointsFactory(address pointsFactoryEnvAddress, address daliaOwner) internal returns (address) {
        if (pointsFactoryEnvAddress != address(0)) {
            return pointsFactoryEnvAddress;
        } else {
            bytes32 salt = keccak256(abi.encode(POINTS_FACTORY_SALT));
            bytes memory encodedArgs = abi.encode(daliaOwner);
            bytes32 initCodeHash = hashInitCode(type(PointsFactory).creationCode, encodedArgs);
            address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
            if (expectedAddress.code.length > 0) {
                console.log("PointsFactory already deployed");
                return expectedAddress;
            } else {
                address pointsFactory = address(new PointsFactory{ salt: salt }(daliaOwner));
                require(expectedAddress == pointsFactory);
                return pointsFactory;
            }
        }
    }

    function _deployWrappedVault() internal returns (address) {
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_SALT));
        bytes32 initCodeHash = hashInitCode(type(WrappedVault).creationCode);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("WrappedVault already deployed");
            return expectedAddress;
        } else {
            address wrappedVault = address(new WrappedVault{ salt: salt }());
            require(expectedAddress == wrappedVault);
            return wrappedVault;
        }
    }

    function _deployDahliaRegistry(address dahliaOwner) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_REGISTRY_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner);
        bytes32 initCodeHash = hashInitCode(type(DahliaRegistry).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("DahliaRegistry already deployed");
            return expectedAddress;
        } else {
            address registry = address(new DahliaRegistry{ salt: salt }(dahliaOwner));
            require(expectedAddress == registry);
            return registry;
        }
    }

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

    function _deployWrappedVaultFactory(
        address wrappedVault,
        address feesRecipient,
        uint256 protocolFee,
        uint256 minimumFrontendFee,
        address dahliaOwner,
        address pointsFactory,
        address dahlia
    ) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(wrappedVault, feesRecipient, protocolFee, minimumFrontendFee, dahliaOwner, pointsFactory, dahlia);
        bytes32 initCodeHash = hashInitCode(type(WrappedVaultFactory).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("WrappedVaultFactory already deployed");
            return expectedAddress;
        } else {
            address wrappedVaultFactory = address(
                new WrappedVaultFactory{ salt: salt }(
                    wrappedVault,
                    feesRecipient,
                    TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
                    TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
                    dahliaOwner,
                    pointsFactory,
                    dahlia
                )
            );
            require(expectedAddress == wrappedVaultFactory);
            return wrappedVaultFactory;
        }
    }

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        address pointsFactoryFromEnv = vm.envOr("POINTS_FACTORY", address(0));
        address pointsFactory = _deployPointsFactory(pointsFactoryFromEnv, dahliaOwner);
        _printContract("POINTS_FACTORY", pointsFactory);
        address wrappedVault = _deployWrappedVault();
        _printContract("WRAPPED_VAULT_IMPLEMENTATION", wrappedVault);
        address registry = _deployDahliaRegistry(dahliaOwner);
        _printContract("REGISTRY", registry);
        // Deploy the contract
        address dahlia = _deployDahlia(dahliaOwner, registry);
        _printContract("DAHLIA_ADDRESS", dahlia);
        address wrappedVaultFactory = _deployWrappedVaultFactory(
            wrappedVault,
            feesRecipient,
            TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
            TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
            dahliaOwner,
            pointsFactory,
            dahlia
        );
        _printContract("WRAPPED_VAULT_FACTORY", wrappedVaultFactory);

        uint256 contractSize = dahlia.code.length;
        console.log("Dahlia contract size:", contractSize);
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        address owner = DahliaRegistry(registry).owner();
        console.log("Dahlia Registry owner:", owner);
        DahliaRegistry(registry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, wrappedVaultFactory);
        vm.stopBroadcast();
    }
}
