// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Metadata } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { CREATE3 } from "../lib/solady/src/utils/CREATE3.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { SafeCastLib } from "../lib/solady/src/utils/SafeCastLib.sol";
import { DahliaPythAdvOracleFactory } from "../src/oracles/contracts/DahliaPythAdvOracleFactory.sol";
import { DahliaPythOracle } from "../src/oracles/contracts/DahliaPythOracle.sol";
import { PythStructs } from "../src/pyth/PythStructs.sol";
import { IPyth } from "../src/pyth/interfaces/IPyth.sol";
import { BaseScript } from "./BaseScript.sol";

contract DahliaPythAdvOracleScript is BaseScript {
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
        DahliaPythAdvOracleFactory oracleFactory = DahliaPythAdvOracleFactory(_envAddress(DEPLOYED_PYTH_ADV_ORACLE_FACTORY));
        _STATIC_ORACLE_ADDRESS = oracleFactory.STATIC_ORACLE_ADDRESS();
        address baseToken = _envAddress("PYTH_ORACLE_BASE_TOKEN");
        int256 baseTokenDecimals = _envInt("PYTH_ORACLE_BASE_TOKEN_DECIMALS");
        bytes32 baseFeed = _envBytes32("PYTH_ORACLE_BASE_FEED");
        int256 baseFeedExpo = _envInt("PYTH_ORACLE_BASE_FEED_EXPO");
        address quoteToken = _envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeed = _envBytes32("PYTH_ORACLE_QUOTE_FEED");
        uint256 baseMaxDelay = _envUint("PYTH_ORACLE_BASE_MAX_DELAY");
        uint256 quoteMaxDelay = _envUint("PYTH_ORACLE_QUOTE_MAX_DELAY");
        DahliaPythOracle.Params memory params = DahliaPythOracle.Params(baseToken, baseFeed, quoteToken, quoteFeed);
        DahliaPythOracle.Delays memory delays =
            DESTINATION.eq("dev") ? DahliaPythOracle.Delays(365 days, 365 days) : DahliaPythOracle.Delays(baseMaxDelay, quoteMaxDelay);
        bytes memory encodedArgs = abi.encode(oracleFactory.timelockAddress(), params, delays, _STATIC_ORACLE_ADDRESS, baseTokenDecimals, baseFeedExpo);
        bytes32 salt = keccak256(encodedArgs);
        address pythOracle = CREATE3.predictDeterministicAddress(salt, address(oracleFactory));
        string memory contractName = string(abi.encodePacked("DEPLOYED_PYTH_ADV_ORACLE_", INDEX));
        if (pythOracle.code.length == 0) {
            //checkPrice(baseFeed, delays.baseMaxDelay);
            checkPrice(quoteFeed, delays.quoteMaxDelay);
            //getDecimals(baseToken);
            getDecimals(quoteToken);
            //getFeedDecimals(baseFeed);
            getFeedDecimals(quoteFeed);

            vm.startBroadcast(deployer);
            pythOracle = oracleFactory.createPythAdvOracle(params, delays, baseTokenDecimals, baseFeedExpo);
            vm.stopBroadcast();

            _printContract(contractName, pythOracle, false);
        } else {
            _printContractAlready(contractName, contractName, pythOracle);
        }
    }
}
