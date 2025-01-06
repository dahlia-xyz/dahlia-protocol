// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DeployDahliaPythOracleFactory is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        console.log("Deployer address:", deployer);
        DahliaPythOracleFactory oracleFactory = _deployDahliaPythOracleFactory(dahliaOwner, pythStaticOracleAddress);
        _printContract("DahliaPythOracleFactory:", address(oracleFactory));
        vm.stopBroadcast();
    }
}
