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
        Dahlia dahlia = Dahlia(envAddress(DEPLOYED_DAHLIA));
        IIrm irm = IIrm(envAddress("IRM"));
        Dahlia.MarketConfig memory config = IDahlia.MarketConfig({
            loanToken: envAddress("LOAN"),
            collateralToken: envAddress("COLLATERAL"),
            oracle: IDahliaOracle(envAddress("ORACLE")),
            irm: irm,
            lltv: envUint("LLTV"),
            liquidationBonusRate: envUint("LIQUIDATION_BONUS_RATE"),
            name: envString("NAME"),
            owner: envAddress("DAHLIA_OWNER")
        });
        DahliaRegistry registry = DahliaRegistry(envAddress(DEPLOYED_REGISTRY));

        vm.startBroadcast(deployer);
        if (registry.getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY) == address(0)) {
            address factory = envAddress(DEPLOYED_WRAPPED_VAULT_FACTORY);
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
