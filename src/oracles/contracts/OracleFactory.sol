// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    ChainlinkOracleMaxDelayParams, ChainlinkOracleParams, ChainlinkWithMaxDelay
} from "./ChainlinkWithMaxDelay.sol";

import {DualOracleChainlinkUniV3} from "./DualOracleChainlinkUniV3.sol";
import {UniswapOraclerParams, UniswapV3SingleTwap} from "./UniswapV3SingleTwap.sol";

contract OracleFactory {
    event ChainlinkOracleCreated(
        address indexed oracleAddress, ChainlinkOracleParams params, ChainlinkOracleMaxDelayParams maxDelays
    );
    event UniswapOracleCreated(address indexed oracleAddress, UniswapOraclerParams params);
    event DualOracleChainlinkUniV3Created(
        address indexed oracleAddress,
        ChainlinkOracleParams chainlinkParams,
        ChainlinkOracleMaxDelayParams chainlinkMaxDelays,
        UniswapOraclerParams uniswapParams
    );

    address public immutable timelockAddress;
    address public immutable uniswapStaticOracleAddress;

    constructor(address timelockAddress_, address uniswapStaticOracleAddress_) {
        timelockAddress = timelockAddress_;
        uniswapStaticOracleAddress = uniswapStaticOracleAddress_;
    }

    function createChainlinkOracle(ChainlinkOracleParams memory params, ChainlinkOracleMaxDelayParams memory maxDelays)
        external
        returns (ChainlinkWithMaxDelay)
    {
        ChainlinkWithMaxDelay oracle = new ChainlinkWithMaxDelay(timelockAddress, params, maxDelays);
        emit ChainlinkOracleCreated(address(oracle), params, maxDelays);
        return oracle;
    }

    function createUniswapOracle(UniswapOraclerParams memory params) external returns (UniswapV3SingleTwap) {
        UniswapV3SingleTwap oracle = new UniswapV3SingleTwap(timelockAddress, params, uniswapStaticOracleAddress);
        emit UniswapOracleCreated(address(oracle), params);
        return oracle;
    }

    function createDualOracleChainlinkUniV3(
        ChainlinkOracleParams memory chainlinkParams,
        ChainlinkOracleMaxDelayParams memory chainlinkMaxDelays,
        UniswapOraclerParams memory uniswapParams
    ) external returns (DualOracleChainlinkUniV3) {
        DualOracleChainlinkUniV3 oracle = new DualOracleChainlinkUniV3(
            timelockAddress, chainlinkParams, chainlinkMaxDelays, uniswapParams, uniswapStaticOracleAddress
        );
        emit DualOracleChainlinkUniV3Created(address(oracle), chainlinkParams, chainlinkMaxDelays, uniswapParams);
        return oracle;
    }
}
