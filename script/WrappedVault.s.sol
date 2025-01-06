// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { IDahlia, IDahliaOracle, IIrm } from "src/core/interfaces/IDahlia.sol";

contract DeployWrappedVault is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaAddress = vm.envAddress("DAHLIA_ADDRESS");
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
        Dahlia dahlia = Dahlia(dahliaAddress);
        if (!dahlia.dahliaRegistry().isIrmAllowed(irm)) {
            dahlia.dahliaRegistry().allowIrm(irm);
        }
        IDahlia.MarketId id = dahlia.deployMarket(config);
        console.log("MarketId:", IDahlia.MarketId.unwrap(id));
        vm.stopBroadcast();
    }
}
