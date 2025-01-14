// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";

import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { IDahlia, IDahliaOracle, IIrm } from "src/core/interfaces/IDahlia.sol";

contract WrappedVaultScript is BaseScript {
    function run() public {
        Dahlia dahlia = Dahlia(vm.envAddress(DEPLOYED_DAHLIA));
        IIrm irm = IIrm(vm.envAddress("IRM"));
        Dahlia.MarketConfig memory config = IDahlia.MarketConfig({
            loanToken: vm.envAddress("LOAN"),
            collateralToken: vm.envAddress("COLLATERAL"),
            oracle: IDahliaOracle(vm.envAddress("ORACLE")),
            irm: irm,
            lltv: vm.envUint("LLTV"),
            liquidationBonusRate: vm.envUint("LIQUIDATION_BONUS_RATE"),
            name: vm.envString("NAME"),
            owner: vm.envAddress("DAHLIA_OWNER")
        });
        DahliaRegistry registry = DahliaRegistry(vm.envAddress(DEPLOYED_REGISTRY));

        vm.startBroadcast(deployer);
        if (registry.getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY) == address(0)) {
            address factory = vm.envAddress(DEPLOYED_WRAPPED_VAULT_FACTORY);
            console.log("Set ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY in registry", factory);
            registry.setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, factory);
        }
        if (!dahlia.dahliaRegistry().isIrmAllowed(irm)) {
            dahlia.dahliaRegistry().allowIrm(irm);
        }
        vm.stopBroadcast();
        IDahlia.MarketId id = dahlia.deployMarket(config);
        console.log("MarketId:", IDahlia.MarketId.unwrap(id));
    }
}
