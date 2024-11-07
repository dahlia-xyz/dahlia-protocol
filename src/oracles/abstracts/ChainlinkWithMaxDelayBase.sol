// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {AggregatorV3InterfaceLib} from "src/oracles/abstracts/AggregatorV3InterfaceLib.sol";
import {Errors} from "src/oracles/helpers/Errors.sol";
import {IChainlinkOracleWithMaxDelay} from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import {ChainlinkOracleMaxDelayParams, ChainlinkOracleParams} from "src/oracles/types/Types.sol";

/// @title ChainlinkWithMaxDelayBase
abstract contract ChainlinkWithMaxDelayBase is IChainlinkOracleWithMaxDelay {
    using FixedPointMathLib for uint256;
    using AggregatorV3InterfaceLib for AggregatorV3Interface;

    /// @notice event is emitted when the max oracle delay is set
    /// @param oldMaxDelays The old max oracle delay
    /// @param newMaxDelays The new max oracle delay
    event SetMaximumOracleDelay(ChainlinkOracleMaxDelayParams oldMaxDelays, ChainlinkOracleMaxDelayParams newMaxDelays);

    uint256 public immutable ORACLE_PRECISION;

    ChainlinkOracleParams public params;
    ChainlinkOracleMaxDelayParams public maxDelays;

    constructor(ChainlinkOracleParams memory _params, ChainlinkOracleMaxDelayParams memory _maxDelays) {
        require(address(_params.baseToken) != address(0), Errors.ZeroAddress());
        require(address(_params.quoteToken) != address(0), Errors.ZeroAddress());

        params = _params;
        maxDelays = _maxDelays;

        uint256 baseTokenDecimals = IERC20Metadata(params.baseToken).decimals();
        uint256 quoteTokenDecimals = IERC20Metadata(params.quoteToken).decimals();

        ORACLE_PRECISION = 10
            ** (
                36 + quoteTokenDecimals + params.quoteFeedPrimary.getDecimals() + params.quoteFeedSecondary.getDecimals()
                    - baseTokenDecimals - params.baseFeedPrimary.getDecimals() - params.baseFeedSecondary.getDecimals()
            );
    }

    function _setMaximumOracleDelays(ChainlinkOracleMaxDelayParams memory _newMaxDelays) internal {
        emit SetMaximumOracleDelay({oldMaxDelays: maxDelays, newMaxDelays: _newMaxDelays});
        maxDelays = _newMaxDelays;
    }

    function setMaximumOracleDelays(ChainlinkOracleMaxDelayParams memory _newMaxOracleDelays) external virtual;

    function _getChainlinkPrice() internal view returns (uint256 price, bool isBadData) {
        (uint256 _basePrimaryPrice, bool _basePrimaryIsBadData) =
            params.baseFeedPrimary.getFeedPrice(maxDelays.baseMaxDelayPrimary);
        (uint256 _baseSecondaryPrice, bool _baseSecondaryIsBadData) =
            params.baseFeedSecondary.getFeedPrice(maxDelays.baseMaxDelaySecondary);
        (uint256 _quotePrimaryPrice, bool _quotePrimaryIsBadData) =
            params.quoteFeedPrimary.getFeedPrice(maxDelays.quoteMaxDelayPrimary);
        (uint256 _quoteSecondaryPrice, bool _quoteSecondaryIsBadData) =
            params.quoteFeedSecondary.getFeedPrice(maxDelays.quoteMaxDelaySecondary);

        isBadData =
            _basePrimaryIsBadData || _baseSecondaryIsBadData || _quotePrimaryIsBadData || _quoteSecondaryIsBadData;

        price =
            ORACLE_PRECISION.mulDiv(_basePrimaryPrice * _baseSecondaryPrice, _quotePrimaryPrice * _quoteSecondaryPrice);
    }
}
