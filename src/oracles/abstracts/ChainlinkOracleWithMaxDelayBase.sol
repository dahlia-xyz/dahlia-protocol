// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { AggregatorV3InterfaceLib } from "src/oracles/abstracts/AggregatorV3InterfaceLib.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";
import { IChainlinkOracleWithMaxDelay } from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";

/// @title ChainlinkOracleWithMaxDelayBase.sol
/// @notice Base contract for Chainlink oracles with max delay settings
abstract contract ChainlinkOracleWithMaxDelayBase is IChainlinkOracleWithMaxDelay {
    using FixedPointMathLib for uint256;
    using AggregatorV3InterfaceLib for AggregatorV3Interface;

    struct Params {
        address baseToken; // Collateral token (e.g., WBTC)
        AggregatorV3Interface baseFeedPrimary;
        AggregatorV3Interface baseFeedSecondary;
        address quoteToken; // Loan token (e.g., USDC)
        AggregatorV3Interface quoteFeedPrimary;
        AggregatorV3Interface quoteFeedSecondary;
    }

    /// @notice Emitted when the max oracle delay is updated
    /// @param oldMaxDelays The previous max oracle delay settings
    /// @param newMaxDelays The new max oracle delay settings
    event SetMaximumOracleDelay(Delays oldMaxDelays, Delays newMaxDelays);

    uint256 public immutable ORACLE_PRECISION;

    Params public params;
    Delays internal _maxDelays;

    constructor(Params memory _params, Delays memory delays) {
        require(address(_params.baseToken) != address(0), Errors.ZeroAddress());
        require(address(_params.quoteToken) != address(0), Errors.ZeroAddress());

        params = _params;
        _maxDelays = delays;

        uint256 baseTokenDecimals = IERC20Metadata(params.baseToken).decimals();
        uint256 quoteTokenDecimals = IERC20Metadata(params.quoteToken).decimals();

        ORACLE_PRECISION = 10
            ** (
                36 + quoteTokenDecimals + params.quoteFeedPrimary.getDecimals() + params.quoteFeedSecondary.getDecimals() - baseTokenDecimals
                    - params.baseFeedPrimary.getDecimals() - params.baseFeedSecondary.getDecimals()
            );
    }

    /// @dev Internal function to update max oracle delays
    /// @param _newMaxDelays The new max delay settings
    function _setMaximumOracleDelays(Delays memory _newMaxDelays) internal {
        emit SetMaximumOracleDelay({ oldMaxDelays: _maxDelays, newMaxDelays: _newMaxDelays });
        _maxDelays = _newMaxDelays;
    }

    /// @notice External function to set new max oracle delays
    /// @param _newMaxOracleDelays The new max delay settings
    function setMaximumOracleDelays(Delays memory _newMaxOracleDelays) external virtual;

    /// @dev Internal function to get the Chainlink price and check data validity
    /// @return price The calculated price
    /// @return isBadData True if any of the data is stale or invalid
    function _getChainlinkPrice() internal view returns (uint256 price, bool isBadData) {
        (uint256 _basePrimaryPrice, bool _basePrimaryIsBadData) = params.baseFeedPrimary.getFeedPrice(_maxDelays.baseMaxDelayPrimary);
        (uint256 _baseSecondaryPrice, bool _baseSecondaryIsBadData) = params.baseFeedSecondary.getFeedPrice(_maxDelays.baseMaxDelaySecondary);
        (uint256 _quotePrimaryPrice, bool _quotePrimaryIsBadData) = params.quoteFeedPrimary.getFeedPrice(_maxDelays.quoteMaxDelayPrimary);
        (uint256 _quoteSecondaryPrice, bool _quoteSecondaryIsBadData) = params.quoteFeedSecondary.getFeedPrice(_maxDelays.quoteMaxDelaySecondary);

        isBadData = _basePrimaryIsBadData || _baseSecondaryIsBadData || _quotePrimaryIsBadData || _quoteSecondaryIsBadData;

        price = ORACLE_PRECISION.mulDiv(_basePrimaryPrice * _baseSecondaryPrice, _quotePrimaryPrice * _quoteSecondaryPrice);
    }

    /// @inheritdoc IChainlinkOracleWithMaxDelay
    function maxDelays() external view returns (Delays memory) {
        return _maxDelays;
    }
}
