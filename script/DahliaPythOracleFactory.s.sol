// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    function run() public {
        vm.startBroadcast(deployer);
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK");
        DahliaPythOracleFactory oracleFactory = _deployDahliaPythOracleFactory(timelockAddress, pythStaticOracleAddress);
        _printContract("PYTH_ORACLE_FACTORY", address(oracleFactory));
        vm.stopBroadcast();
    }
}
