// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IDahliaOracle {
    /// @notice Returns the  price and is the price is bad
    /// @return price The price
    /// @return isBadData True if the data is stale or negative
    function getPrice() external view returns (uint256, bool);
}
