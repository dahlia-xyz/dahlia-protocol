// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ChainlinkOracleWithMaxDelay } from "./ChainlinkOracleWithMaxDelay.sol";
import { DualOracleChainlinkUniV3 } from "./DualOracleChainlinkUniV3.sol";
import { UniswapOracleV3SingleTwap } from "./UniswapOracleV3SingleTwap.sol";

contract DahliaOracleFactory {
    mapping(address => bool) public isDahliaOracle;

    event ChainlinkOracleCreated(address indexed oracleAddress, ChainlinkOracleWithMaxDelay.Params params, ChainlinkOracleWithMaxDelay.Delays maxDelays);
    event UniswapOracleCreated(address indexed oracleAddress, UniswapOracleV3SingleTwap.OracleParams params);
    event DualOracleChainlinkUniV3Created(
        address indexed oracleAddress,
        ChainlinkOracleWithMaxDelay.Params chainlinkParams,
        ChainlinkOracleWithMaxDelay.Delays chainlinkMaxDelays,
        UniswapOracleV3SingleTwap.OracleParams uniswapParams
    );
    event StablePriceOracleCreated(address indexed oracleAddress, uint256 price);

    address public immutable timelockAddress;
    address public immutable uniswapStaticOracleAddress;

    constructor(address timelockAddress_, address uniswapStaticOracleAddress_) {
        timelockAddress = timelockAddress_;
        uniswapStaticOracleAddress = uniswapStaticOracleAddress_;
    }

    function createChainlinkOracle(ChainlinkOracleWithMaxDelay.Params memory params, ChainlinkOracleWithMaxDelay.Delays memory maxDelays)
        external
        returns (ChainlinkOracleWithMaxDelay)
    {
        ChainlinkOracleWithMaxDelay oracle = new ChainlinkOracleWithMaxDelay(timelockAddress, params, maxDelays);
        isDahliaOracle[address(oracle)] = true;
        emit ChainlinkOracleCreated(address(oracle), params, maxDelays);
        return oracle;
    }

    function createUniswapOracle(UniswapOracleV3SingleTwap.OracleParams memory params) external returns (UniswapOracleV3SingleTwap) {
        UniswapOracleV3SingleTwap oracle = new UniswapOracleV3SingleTwap(timelockAddress, params, uniswapStaticOracleAddress);
        isDahliaOracle[address(oracle)] = true;
        emit UniswapOracleCreated(address(oracle), params);
        return oracle;
    }

    function createDualOracleChainlinkUniV3(
        ChainlinkOracleWithMaxDelay.Params memory chainlinkParams,
        ChainlinkOracleWithMaxDelay.Delays memory chainlinkMaxDelays,
        UniswapOracleV3SingleTwap.OracleParams memory uniswapParams
    ) external returns (DualOracleChainlinkUniV3) {
        DualOracleChainlinkUniV3 oracle =
            new DualOracleChainlinkUniV3(timelockAddress, chainlinkParams, chainlinkMaxDelays, uniswapParams, uniswapStaticOracleAddress);
        isDahliaOracle[address(oracle)] = true;
        emit DualOracleChainlinkUniV3Created(address(oracle), chainlinkParams, chainlinkMaxDelays, uniswapParams);
        return oracle;
    }
}
