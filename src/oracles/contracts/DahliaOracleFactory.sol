// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ChainlinkOracleWithMaxDelay } from "./ChainlinkOracleWithMaxDelay.sol";
import { DualOracleChainlinkUniV3 } from "./DualOracleChainlinkUniV3.sol";

import { PythOracle } from "./PythOracle.sol";
import { UniswapOracleV3SingleTwap } from "./UniswapOracleV3SingleTwap.sol";

contract DahliaOracleFactory {
    event SetTimelockAddress(address indexed timelockAddress);
    event SetUniswapStaticOracleAddress(address indexed uniswapStaticOracleAddres);
    event ChainlinkOracleCreated(address indexed oracleAddress, ChainlinkOracleWithMaxDelay.Params params, ChainlinkOracleWithMaxDelay.Delays maxDelays);
    event UniswapOracleCreated(address indexed oracleAddress, UniswapOracleV3SingleTwap.OracleParams params);
    event DualOracleChainlinkUniV3Created(
        address indexed oracleAddress,
        ChainlinkOracleWithMaxDelay.Params chainlinkParams,
        ChainlinkOracleWithMaxDelay.Delays chainlinkMaxDelays,
        UniswapOracleV3SingleTwap.OracleParams uniswapParams
    );

    address public immutable timelockAddress;
    address public immutable uniswapStaticOracleAddress;
    address public immutable pythStaticOracleAddress;

    constructor(address timelockAddress_, address uniswapStaticOracleAddress_, address pythStaticOracleAddress_) {
        timelockAddress = timelockAddress_;
        emit SetTimelockAddress(timelockAddress_);
        uniswapStaticOracleAddress = uniswapStaticOracleAddress_;
        emit SetUniswapStaticOracleAddress(uniswapStaticOracleAddress_);
        pythStaticOracleAddress = pythStaticOracleAddress_;
    }

    function createChainlinkOracle(ChainlinkOracleWithMaxDelay.Params memory params, ChainlinkOracleWithMaxDelay.Delays memory maxDelays)
        external
        returns (ChainlinkOracleWithMaxDelay)
    {
        ChainlinkOracleWithMaxDelay oracle = new ChainlinkOracleWithMaxDelay(timelockAddress, params, maxDelays);
        emit ChainlinkOracleCreated(address(oracle), params, maxDelays);
        return oracle;
    }

    function createUniswapOracle(UniswapOracleV3SingleTwap.OracleParams memory params) external returns (UniswapOracleV3SingleTwap) {
        UniswapOracleV3SingleTwap oracle = new UniswapOracleV3SingleTwap(timelockAddress, params, uniswapStaticOracleAddress);
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
        emit DualOracleChainlinkUniV3Created(address(oracle), chainlinkParams, chainlinkMaxDelays, uniswapParams);
        return oracle;
    }

    function createPythOracle(PythOracle.Params memory params) external returns (PythOracle) {
        PythOracle oracle = new PythOracle(timelockAddress, params, pythStaticOracleAddress);
        // emit DualOracleChainlinkUniV3Created(address(oracle), chainlinkParams, chainlinkMaxDelays, uniswapParams);
        return oracle;
    }
}
