// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Metadata } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "../lib/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "../lib/pyth-sdk-solidity/PythStructs.sol";
import { CREATE3 } from "../lib/solady/src/utils/CREATE3.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { SafeCastLib } from "../lib/solady/src/utils/SafeCastLib.sol";
import { DahliaPythV2Oracle } from "../src/oracles/contracts/DahliaPythV2Oracle.sol";
import { DahliaPythV2OracleFactory } from "../src/oracles/contracts/DahliaPythV2OracleFactory.sol";
import { BaseScript } from "./BaseScript.sol";

contract DahliaPythV2OracleScript is BaseScript {
    using LibString for *;
    using SafeCastLib for *;

    address internal _STATIC_ORACLE_ADDRESS;

    function getDecimals(address token) internal view returns (int32) {
        return (IERC20Metadata(token).decimals()).toInt32();
    }

    function getFeedExpo(bytes32 feedId) internal view returns (int32) {
        if (feedId == bytes32(0)) {
            return 0; // Return 0 if feed is zero
        }
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
        DahliaPythV2OracleFactory oracleFactory = DahliaPythV2OracleFactory(_envAddress(DEPLOYED_PYTH_V2_ORACLE_FACTORY));
        _STATIC_ORACLE_ADDRESS = oracleFactory.STATIC_ORACLE_ADDRESS();
        address baseToken = _envAddress("PYTH_ORACLE_BASE_TOKEN");
        bytes32 baseFeedPrimary = _envBytes32("PYTH_ORACLE_BASE_PRIMARY_FEED");
        bytes32 baseFeedSecondary = _envBytes32("PYTH_ORACLE_BASE_SECONDARY_FEED");
        address quoteToken = _envAddress("PYTH_ORACLE_QUOTE_TOKEN");
        bytes32 quoteFeedPrimary = _envBytes32("PYTH_ORACLE_QUOTE_PRIMARY_FEED");
        bytes32 quoteFeedSecondary = _envBytes32("PYTH_ORACLE_QUOTE_SECONDARY_FEED");
        uint256 baseMaxDelayPrimary = _envUint("PYTH_ORACLE_BASE_MAX_DELAY_PRIMARY");
        uint256 baseMaxDelaySecondary = _envUint("PYTH_ORACLE_BASE_MAX_DELAY_SECONDARY");
        uint256 quoteMaxDelayPrimary = _envUint("PYTH_ORACLE_QUOTE_MAX_DELAY_PRIMARY");
        uint256 quoteMaxDelaySecondary = _envUint("PYTH_ORACLE_QUOTE_MAX_DELAY_SECONDARY");
        DahliaPythV2Oracle.Params memory params = DahliaPythV2Oracle.Params({
            baseToken: baseToken,
            baseFeedPrimary: baseFeedPrimary,
            baseFeedSecondary: baseFeedSecondary,
            quoteToken: quoteToken,
            quoteFeedPrimary: quoteFeedPrimary,
            quoteFeedSecondary: quoteFeedSecondary
        });
        DahliaPythV2Oracle.Delays memory delays = DESTINATION.eq("dev")
            ? DahliaPythV2Oracle.Delays(365 days, 365 days, 365 days, 365 days)
            : DahliaPythV2Oracle.Delays({
                baseMaxDelayPrimary: baseMaxDelayPrimary,
                baseMaxDelaySecondary: baseMaxDelaySecondary,
                quoteMaxDelayPrimary: quoteMaxDelayPrimary,
                quoteMaxDelaySecondary: quoteMaxDelaySecondary
            });
        bytes memory encodedArgs = abi.encode(oracleFactory.timelockAddress(), params, delays, _STATIC_ORACLE_ADDRESS);
        bytes32 salt = keccak256(encodedArgs);
        address pythOracle = CREATE3.predictDeterministicAddress(salt, address(oracleFactory));
        string memory contractName = string(abi.encodePacked("DEPLOYED_PYTH_V2_ORACLE_", INDEX));
        if (pythOracle.code.length == 0) {
            checkPrice(baseFeedPrimary, delays.baseMaxDelayPrimary);
            checkPrice(baseFeedSecondary, delays.baseMaxDelaySecondary);
            checkPrice(quoteFeedPrimary, delays.quoteMaxDelayPrimary);
            checkPrice(quoteFeedSecondary, delays.quoteMaxDelaySecondary);
            getDecimals(baseToken);
            getDecimals(quoteToken);
            getFeedExpo(baseFeedPrimary);
            getFeedExpo(baseFeedSecondary);
            getFeedExpo(quoteFeedPrimary);
            getFeedExpo(quoteFeedSecondary);

            vm.startBroadcast(deployer);
            pythOracle = oracleFactory.createPythV2Oracle(params, delays);
            vm.stopBroadcast();

            _printContract(contractName, pythOracle, false);
        } else {
            _printContractAlready(contractName, contractName, pythOracle);
        }
    }
}
