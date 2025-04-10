// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from "../lib/forge-std/src/console.sol";

import { PythAggregatorV3 } from "../src/pyth/PythAggregatorV3.sol";
import { BaseScript } from "./BaseScript.sol";

contract PythAggregatorV3Script is BaseScript {
    function run() external {
        string memory INDEX = _envString(INDEX);
        string memory contractName = string(abi.encodePacked("DEPLOYED_PYTH_AGGREGATOR_", INDEX));
        address marketAddress = _envOr(contractName, address(0));
        if (marketAddress.code.length == 0 || marketAddress == address(0)) {
            address pythStaticOracleAddress = _envAddress(PYTH_STATIC_ORACLE_ADDRESS);
            bytes32 feed = _envBytes32("PYTH_FEED");

            vm.startBroadcast(deployer);
            PythAggregatorV3 ethAggregator = new PythAggregatorV3(pythStaticOracleAddress, feed);
            vm.stopBroadcast();
            _printContract(contractName, address(ethAggregator), false);
        } else {
            console.log(contractName, "already deployed");
        }
    }
}
