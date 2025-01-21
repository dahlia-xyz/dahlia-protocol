// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { DahliaPythOracle } from "src/oracles/contracts/DahliaPythOracle.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleScript is BaseScript {
    using LibString for *;
    using SafeCastLib for *;

    address internal _STATIC_ORACLE_ADDRESS;

    function getDecimals(address token) internal view returns (int32) {
        return (IERC20Metadata(token).decimals()).toInt32();
    }

    function getFeedDecimals(bytes32 feedId) internal view returns (int32) {
        return IPyth(_STATIC_ORACLE_ADDRESS).getPriceUnsafe(feedId).expo;
    }

    function checkPrice(bytes32 feed, uint256 maxDelay) internal view {
        require(maxDelay != 0, "Max delay should not be zero for none zero feed");
        PythStructs.Price memory basePrice = IPyth(_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(feed, maxDelay);
        require(basePrice.price > 0, string(abi.encodePacked("price should not be bad data maxDelay=", maxDelay.toString())));
    }

    function run() public {
        string memory INDEX = _envString(INDEX);
        string memory DESTINATION = _envString(DESTINATION);
        DahliaPythOracleFactory oracleFactory = DahliaPythOracleFactory(_envAddress(DEPLOYED_PYTH_ORACLE_FACTORY));
        _STATIC_ORACLE_ADDRESS = oracleFactory.STATIC_ORACLE_ADDRESS();
        address baseToken = _envAddress("PYTH_ORACLE_BASE_TOKEN");
        bytes32 baseFeed = _envBytes32("PYTH_ORACLE_BASE_FEED");
        address quoteToken = _envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeed = _envBytes32("PYTH_ORACLE_QUOTE_FEED");
        uint256 baseMaxDelay = _envUint("PYTH_ORACLE_BASE_MAX_DELAY");
        uint256 quoteMaxDelay = _envUint("PYTH_ORACLE_QUOTE_MAX_DELAY");
        DahliaPythOracle.Params memory params = DahliaPythOracle.Params(baseToken, baseFeed, quoteToken, quoteFeed);
        DahliaPythOracle.Delays memory delays =
            DESTINATION.eq("remote") ? DahliaPythOracle.Delays(baseMaxDelay, quoteMaxDelay) : DahliaPythOracle.Delays(365 days, 365 days);
        bytes memory encodedArgs = abi.encode(oracleFactory.timelockAddress(), params, delays, _STATIC_ORACLE_ADDRESS);
        bytes32 salt = keccak256(encodedArgs);
        address pythOracle = CREATE3.predictDeterministicAddress(salt, address(oracleFactory));
        string memory contractName = string(abi.encodePacked("DEPLOYED_PYTH_ORACLE_", INDEX));
        if (pythOracle.code.length == 0) {
            checkPrice(baseFeed, delays.baseMaxDelay);
            checkPrice(quoteFeed, delays.quoteMaxDelay);
            getDecimals(baseToken);
            getDecimals(quoteToken);
            getFeedDecimals(baseFeed);
            getFeedDecimals(quoteFeed);
            vm.startBroadcast(deployer);
            pythOracle = oracleFactory.createPythOracle(params, delays);
            _printContract(contractName, pythOracle, false);
            vm.stopBroadcast();
        } else {
            console.log(pythOracle, "already deployed");
        }
    }
}
