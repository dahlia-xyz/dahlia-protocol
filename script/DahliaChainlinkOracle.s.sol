// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { console } from "@forge-std/console.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { AggregatorV3InterfaceLib } from "src/oracles/abstracts/AggregatorV3InterfaceLib.sol";
import { DahliaChainlinkOracle } from "src/oracles/contracts/DahliaChainlinkOracle.sol";
import { DahliaChainlinkOracleFactory } from "src/oracles/contracts/DahliaChainlinkOracleFactory.sol";

contract DahliaPythOracleScript is BaseScript {
    using LibString for *;
    using AggregatorV3InterfaceLib for AggregatorV3Interface;

    function checkPrice(AggregatorV3Interface feed, uint256 maxDelay) internal view {
        if (address(feed) == address(0)) return;
        require(maxDelay != 0, "Max delay should not be zero for none zero feed");
        (uint256 price, bool isBadPrice) = feed.getFeedPrice(maxDelay);
        require(price > 0, "price should not be zero");
        require(
            isBadPrice == false, string(abi.encodePacked("price should not be bad data feed=", address(feed).toHexString(), " maxDelay=", maxDelay.toString()))
        );
    }

    function run() public {
        DahliaChainlinkOracleFactory oracleFactory = DahliaChainlinkOracleFactory(_envAddress(DEPLOYED_CHAINLINK_ORACLE_FACTORY));
        string memory INDEX = _envString(INDEX);
        string memory DESTINATION = _envString(DESTINATION);
        address baseToken = _envAddress("CHAINLINK_ORACLE_BASE_TOKEN");
        AggregatorV3Interface baseFeedPrimary = AggregatorV3Interface(_envAddress("CHAINLINK_ORACLE_BASE_FEED_PRIMARY"));
        AggregatorV3Interface baseFeedSecondary = AggregatorV3Interface(_envOr("CHAINLINK_ORACLE_BASE_FEED_SECONDARY", address(0)));
        address quoteToken = _envOr("CHAINLINK_ORACLE_QUOTE_TOKEN", address(0));
        AggregatorV3Interface quoteFeedPrimary = AggregatorV3Interface(_envOr("CHAINLINK_ORACLE_QUOTE_FEED_PRIMARY", address(0)));
        AggregatorV3Interface quoteFeedSecondary = AggregatorV3Interface(_envOr("CHAINLINK_ORACLE_QUOTE_FEED_SECONDARY", address(0)));
        DahliaChainlinkOracle.Params memory params =
            DahliaChainlinkOracle.Params(baseToken, baseFeedPrimary, baseFeedSecondary, quoteToken, quoteFeedPrimary, quoteFeedSecondary);
        uint256 baseMaxDelayPrimary = _envUint("CHAINLINK_ORACLE_BASE_PRIMARY_MAX_DELAY");
        uint256 baseMaxDelaySecondary = _envOr("CHAINLINK_ORACLE_BASE_SECONDARY_MAX_DELAY", 0);
        uint256 quoteMaxDelayPrimary = _envOr("CHAINLINK_ORACLE_QUOTE_PRIMARY_MAX_DELAY", 0);
        uint256 quoteMaxDelaySecondary = _envOr("CHAINLINK_ORACLE_QUOTE_SECONDARY_MAX_DELAY", 0);
        DahliaChainlinkOracle.Delays memory delays = DESTINATION.eq("remote")
            ? DahliaChainlinkOracle.Delays(baseMaxDelayPrimary, baseMaxDelaySecondary, quoteMaxDelayPrimary, quoteMaxDelaySecondary)
            : DahliaChainlinkOracle.Delays(365 days, 365 days, 365 days, 365 days);

        bytes memory encodedArgs = abi.encode(oracleFactory.timelockAddress(), params, delays);
        bytes32 salt = keccak256(encodedArgs);
        address oracle = CREATE3.predictDeterministicAddress(salt, address(oracleFactory));
        string memory contractName = string(abi.encodePacked("DEPLOYED_CHAINLINK_ORACLE_", INDEX));
        if (oracle.code.length == 0) {
            checkPrice(baseFeedPrimary, baseMaxDelayPrimary);
            checkPrice(baseFeedSecondary, baseMaxDelaySecondary);
            checkPrice(quoteFeedPrimary, quoteMaxDelayPrimary);
            checkPrice(quoteFeedSecondary, quoteMaxDelaySecondary);
            vm.startBroadcast(deployer);
            oracle = oracleFactory.createChainlinkOracle(params, delays);
            _printContract(contractName, oracle, false);
            vm.stopBroadcast();
        } else {
            console.log(oracle, "already deployed");
        }
    }
}
