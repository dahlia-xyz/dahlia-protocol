// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PythOracle } from "src/oracles/contracts/PythOracle.sol";

contract DeployPythOracle is BaseScript {
    function getPythOracleDeployData() internal returns (PythOracle.Params memory params, PythOracle.Delays memory delays) {
        address baseToken = vm.envAddress("PYTH_ORACLE_BASE_TOKEN");
        bytes32 baseFeed = vm.envBytes32("PYTH_ORACLE_BASE_FEED");
        address quoteToken = vm.envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeed = vm.envBytes32("PYTH_ORACLE_QUOTE_FEED");
        uint256 baseMaxDelay = vm.envUint("PYTH_ORACLE_BASE_MAX_DELAY");
        uint256 quoteMaxDelay = vm.envUint("PYTH_ORACLE_QUOTE_MAX_DELAY");
        params = PythOracle.Params(baseToken, baseFeed, quoteToken, quoteFeed);
        delays = PythOracle.Delays(baseMaxDelay, quoteMaxDelay);
    }

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        console.log("Deployer address:", deployer);
        (PythOracle.Params memory params, PythOracle.Delays memory delays) = getPythOracleDeployData();
        PythOracle pythOracle = new PythOracle(dahliaOwner, params, delays, pythStaticOracleAddress);
        _printContract("PythOracle:", address(pythOracle));
        vm.stopBroadcast();
    }
}
