// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChainlinkWithMaxDelay} from "./ChainlinkWithMaxDelay.sol";
import {DualOracleChainlinkUniV3} from "./DualOracleChainlinkUniV3.sol";
import {UniswapV3SingleTwap} from "./UniswapV3SingleTwap.sol";

contract OracleFactory {
    event ChainlinkOracleCreated(
        address indexed oracleAddress, ChainlinkWithMaxDelay.Params params, ChainlinkWithMaxDelay.Delays maxDelays
    );
    event UniswapOracleCreated(address indexed oracleAddress, UniswapV3SingleTwap.OracleParams params);
    event DualOracleChainlinkUniV3Created(
        address indexed oracleAddress,
        ChainlinkWithMaxDelay.Params chainlinkParams,
        ChainlinkWithMaxDelay.Delays chainlinkMaxDelays,
        UniswapV3SingleTwap.OracleParams uniswapParams
    );

    address public immutable timelockAddress;
    address public immutable uniswapStaticOracleAddress;

    constructor(address timelockAddress_, address uniswapStaticOracleAddress_) {
        timelockAddress = timelockAddress_;
        uniswapStaticOracleAddress = uniswapStaticOracleAddress_;
    }

    function createChainlinkOracle(
        ChainlinkWithMaxDelay.Params memory params,
        ChainlinkWithMaxDelay.Delays memory maxDelays
    ) external returns (ChainlinkWithMaxDelay) {
        ChainlinkWithMaxDelay oracle = new ChainlinkWithMaxDelay(timelockAddress, params, maxDelays);
        emit ChainlinkOracleCreated(address(oracle), params, maxDelays);
        return oracle;
    }

    function createUniswapOracle(UniswapV3SingleTwap.OracleParams memory params)
        external
        returns (UniswapV3SingleTwap)
    {
        UniswapV3SingleTwap oracle = new UniswapV3SingleTwap(timelockAddress, params, uniswapStaticOracleAddress);
        emit UniswapOracleCreated(address(oracle), params);
        return oracle;
    }

    function createDualOracleChainlinkUniV3(
        ChainlinkWithMaxDelay.Params memory chainlinkParams,
        ChainlinkWithMaxDelay.Delays memory chainlinkMaxDelays,
        UniswapV3SingleTwap.OracleParams memory uniswapParams
    ) external returns (DualOracleChainlinkUniV3) {
        DualOracleChainlinkUniV3 oracle = new DualOracleChainlinkUniV3(
            timelockAddress, chainlinkParams, chainlinkMaxDelays, uniswapParams, uniswapStaticOracleAddress
        );
        emit DualOracleChainlinkUniV3Created(address(oracle), chainlinkParams, chainlinkMaxDelays, uniswapParams);
        return oracle;
    }
}
