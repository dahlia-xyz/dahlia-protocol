// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Script } from "@forge-std/Script.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { TestConstants } from "test/common/TestConstants.sol";

contract DeployDahlia is Script {
    using LibString for *;

    uint256 blockNumber;

    function _printContract(string memory prefix, address addr) internal {
        string memory host = "http://localhost/";
        blockNumber++;
        string memory blockUrl = string(abi.encodePacked(host, "block/", (blockNumber).toString()));
        string memory addressUrl = string(abi.encodePacked(host, "address/", (addr).toHexString()));
        console.log(prefix, addressUrl, blockUrl);
    }

    function run() public {
        blockNumber = vm.getBlockNumber();
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // Use environment variable for security
        vm.startBroadcast(deployerPrivateKey);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployerAddress);
        address pointsFactoryFromEnv = vm.envOr("POINTS_FACTORY", address(0));
        address pointsFactory = pointsFactoryFromEnv == address(0) ? address(new PointsFactory(dahliaOwner)) : pointsFactoryFromEnv;
        _printContract("PointsFactory:              ", pointsFactory);
        address wrappedVault = address(new WrappedVault());
        _printContract("WrappedVault Implementation:", wrappedVault);
        address registry = address(new DahliaRegistry(dahliaOwner));
        _printContract("Registry:                   ", registry);
        // Deploy the contract
        address dahlia = address(new Dahlia(dahliaOwner, registry));
        _printContract("Dahlia:                     ", dahlia);
        address wrappedVaultFactory = address(
            new WrappedVaultFactory(
                wrappedVault,
                feesRecipient,
                TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
                TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
                dahliaOwner,
                pointsFactory,
                dahlia
            )
        );
        _printContract("WrappedVaultFactory:        ", wrappedVaultFactory);
        uint256 contractSize = dahlia.code.length;
        console.log("Dahlia contract size:", contractSize);
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        DahliaRegistry(registry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, wrappedVaultFactory);
        vm.stopBroadcast();
    }
}
