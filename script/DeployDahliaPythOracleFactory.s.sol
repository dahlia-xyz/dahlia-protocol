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
        uint256 timelockDelay = vm.envUint("TIMELOCK_DELAY");
        address timelockAddress = _calculateTimelockExpectedAddress(dahliaOwner, timelockDelay);
        DahliaPythOracleFactory oracleFactory = _deployDahliaPythOracleFactory(timelockAddress, pythStaticOracleAddress);
        _printContract("DahliaPythOracleFactory:", address(oracleFactory));
        vm.stopBroadcast();
    }
}
