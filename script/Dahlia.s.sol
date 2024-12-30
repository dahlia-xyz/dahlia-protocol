// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { TestConstants } from "test/common/TestConstants.sol";

contract DeployDahlia is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        console.log("Deployer address:", deployer);
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
        IrmFactory irmFactory = new IrmFactory();
        _printContract("IrmFactory:                ", address(irmFactory));

        uint64 ZERO_UTIL_RATE = 158_247_046;
        uint64 MIN_FULL_UTIL_RATE = 1_582_470_460;
        uint64 MAX_FULL_UTIL_RATE = 3_164_940_920_000;

        IIrm irm = irmFactory.createVariableIrm(
            VariableIrm.Config({
                minTargetUtilization: 75 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                maxTargetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                targetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                minFullUtilizationRate: MIN_FULL_UTIL_RATE,
                maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
                zeroUtilizationRate: ZERO_UTIL_RATE,
                rateHalfLife: 172_800,
                targetRatePercent: 0.2e18
            })
        );
        _printContract("Irm:                        ", address(irm));

        // Oracle

        uint256 contractSize = dahlia.code.length;
        console.log("Dahlia contract size:", contractSize);
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        DahliaRegistry(registry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, wrappedVaultFactory);
        vm.stopBroadcast();
    }
}
