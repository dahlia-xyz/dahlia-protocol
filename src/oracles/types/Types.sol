// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

struct UniswapOraclerParams {
    address uniswapV3PairAddress;
    uint32 twapDuration;
    address baseToken;
    address quoteToken;
}

struct ChainlinkOracleParams {
    address baseToken; // base token is collateral token (example WBTC)
    AggregatorV3Interface baseFeedPrimary;
    AggregatorV3Interface baseFeedSecondary;
    address quoteToken; // base token is loan token (example USDC)
    AggregatorV3Interface quoteFeedPrimary;
    AggregatorV3Interface quoteFeedSecondary;
}

struct ChainlinkOracleMaxDelayParams {
    uint256 baseMaxDelayPrimary;
    uint256 baseMaxDelaySecondary;
    uint256 quoteMaxDelayPrimary;
    uint256 quoteMaxDelaySecondary;
}
