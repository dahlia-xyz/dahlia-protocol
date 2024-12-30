// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title Pyth Oracle Interface with Max Price Age
/// @notice Interface to manage maximum price age for Pyth oracle data
interface IPythOracle {
    /// @notice Returns the current max price age settings
    function getMaxPriceAge() external view returns (uint256 maxPriceAge);

    /// @notice Set new maximum price age for oracle data to determine if it's stale
    /// @dev Only callable by the timelock address
    /// @param _maxPriceAge New maximum price age
    function setMaxPriceAge(uint256 _maxPriceAge) external;
}
