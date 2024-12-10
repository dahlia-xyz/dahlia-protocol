// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title Chainlink Oracle Interface with Max Delay
/// @notice Interface to manage maximum delays for Chainlink oracle data
interface IChainlinkOracleWithMaxDelay {
    /// @notice Struct to hold max delay settings for primary and secondary data sources
    struct Delays {
        uint256 baseMaxDelayPrimary; // Maximum delay for primary base data
        uint256 baseMaxDelaySecondary; // Maximum delay for secondary base data
        uint256 quoteMaxDelayPrimary; // Maximum delay for primary quote data
        uint256 quoteMaxDelaySecondary; // Maximum delay for secondary quote data
    }

    /// @notice Returns the current max delay settings
    function maxDelays() external view returns (Delays memory maxDelays);

    /// @notice Set new maximum delays for oracle data to determine if it's stale
    /// @dev Only callable by the timelock address
    /// @param _newMaxOracleDelays New maximum delay settings
    function setMaximumOracleDelays(Delays memory _newMaxOracleDelays) external;
}
