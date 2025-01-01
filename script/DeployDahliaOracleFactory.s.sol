// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { DahliaOracleFactory } from "src/oracles/contracts/DahliaOracleFactory.sol";

contract DeployDahliaOracleFactory is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address uniswapStaticOracleAddress = vm.envAddress("UNISWAP_STATIC_ORACLE_ADDRESS");
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        console.log("Deployer address:", deployer);
        DahliaOracleFactory oracleFactory = _deployDahliaOracleFactory(dahliaOwner, uniswapStaticOracleAddress, pythStaticOracleAddress);
        _printContract("DahliaOracleFactory:", address(oracleFactory));
        vm.stopBroadcast();
    }
}
