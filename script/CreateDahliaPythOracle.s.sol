// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaPythOracle } from "src/oracles/contracts/DahliaPythOracle.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DeployPythOracle is BaseScript {
    function getPythOracleDeployData() internal view returns (DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays) {
        address baseToken = vm.envAddress("PYTH_ORACLE_BASE_TOKEN");
        bytes32 baseFeed = vm.envBytes32("PYTH_ORACLE_BASE_FEED");
        address quoteToken = vm.envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeed = vm.envBytes32("PYTH_ORACLE_QUOTE_FEED");
        uint256 baseMaxDelay = vm.envUint("PYTH_ORACLE_BASE_MAX_DELAY");
        uint256 quoteMaxDelay = vm.envUint("PYTH_ORACLE_QUOTE_MAX_DELAY");
        params = DahliaPythOracle.Params(baseToken, baseFeed, quoteToken, quoteFeed);
        delays = DahliaPythOracle.Delays(baseMaxDelay, quoteMaxDelay);
    }

    function run() public {
        vm.startBroadcast(deployer);
        DahliaPythOracleFactory oracleFactory = DahliaPythOracleFactory(vm.envAddress("PYTH_ORACLE_FACTORY"));
        string memory INDEX = vm.envString("INDEX");
        (DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays) = getPythOracleDeployData();
        DahliaPythOracle pythOracle = oracleFactory.createPythOracle(params, delays);
        string memory contractName = string(abi.encodePacked("PYTH_ORACLE_", INDEX));
        _printContract("PythOracle:", address(pythOracle), contractName);
        vm.stopBroadcast();
    }
}
