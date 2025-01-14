// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";

/// @dev copied used methods from https://github.com/lidofinance/core/blob/master/contracts/0.6.12/WstETH.sol
interface IWstETH is IERC20Metadata {
    /**
     * @notice Get amount of stETH for a one wstETH
     * @return Amount of stETH for 1 wstETH
     */
    function stEthPerToken() external view returns (uint256);
}

/// @title ChainlinkCompatWstETHToETHPriceFeed
/// @notice Oracle to convert wstETH-ETH using a stETH-ETH Chainlink feed.
/// @dev adapted from https://github.com/lidofinance/wsteth-eth-price-feed/blob/main/contracts/AAVECompatWstETHToETHPriceFeed.sol
contract ChainlinkCompatWstETHToETHPriceFeed is AggregatorV3Interface {
    error UnsupportedMethod();
    error BadWstETHToStETH();

    struct Params {
        address wstEth;
        AggregatorV3Interface stEthToEthFeed;
    }

    event ParamsUpdated(Params params);

    uint8 internal immutable _DECIMAL;
    int256 internal immutable _WST_ETH_PRECISION;
    IWstETH public immutable WST_ETH;
    AggregatorV3Interface public immutable STETH_TO_ETH_FEED;

    uint256 public stEthToEthMaxDelay;

    constructor(Params memory params) {
        require(params.wstEth != address(0), Errors.ZeroAddress());
        require(address(params.stEthToEthFeed) != address(0), Errors.ZeroAddress());

        WST_ETH = IWstETH(params.wstEth);
        STETH_TO_ETH_FEED = params.stEthToEthFeed;
        _DECIMAL = STETH_TO_ETH_FEED.decimals();
        _WST_ETH_PRECISION = int256(10 ** WST_ETH.decimals());

        emit ParamsUpdated(params);
    }

    function decimals() external view returns (uint8) {
        return _DECIMAL;
    }

    function description() external pure returns (string memory) {
        return "WSTETH / ETH";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert UnsupportedMethod();
    }

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        int256 wstETHToStETH = int256(WST_ETH.stEthPerToken());
        require(wstETHToStETH > 0, BadWstETHToStETH());

        (roundId, answer, startedAt, updatedAt, answeredInRound) = STETH_TO_ETH_FEED.latestRoundData();
        // TODO: do we need this?
        //        if (answer > 10 ** _decimal) {
        //            answer = 10 ** _decimal;
        //        }
        answer = answer * wstETHToStETH / _WST_ETH_PRECISION;
    }
}
