// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { DahliaPythOracle } from "src/oracles/contracts/DahliaPythOracle.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleScript is BaseScript {
    function getPythOracleDeployData() internal view returns (DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays) {
        address baseToken = envAddress("PYTH_ORACLE_BASE_TOKEN");
        bytes32 baseFeed = envBytes32("PYTH_ORACLE_BASE_FEED");
        address quoteToken = envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeed = envBytes32("PYTH_ORACLE_QUOTE_FEED");
        uint256 baseMaxDelay = envUint("PYTH_ORACLE_BASE_MAX_DELAY");
        uint256 quoteMaxDelay = envUint("PYTH_ORACLE_QUOTE_MAX_DELAY");
        params = DahliaPythOracle.Params(baseToken, baseFeed, quoteToken, quoteFeed);
        delays = DahliaPythOracle.Delays(baseMaxDelay, quoteMaxDelay);
    }

    function run() public {
        vm.startBroadcast(deployer);
        DahliaPythOracleFactory oracleFactory = DahliaPythOracleFactory(envAddress(DEPLOYED_PYTH_ORACLE_FACTORY));
        string memory INDEX = envString("INDEX");
        (DahliaPythOracle.Params memory params, DahliaPythOracle.Delays memory delays) = getPythOracleDeployData();
        address pythOracle = oracleFactory.createPythOracle(params, delays);
        string memory contractName = string(abi.encodePacked("DEPLOYED_PYTH_ORACLE_", INDEX));
        _printContract(contractName, pythOracle);
        vm.stopBroadcast();
    }
}
