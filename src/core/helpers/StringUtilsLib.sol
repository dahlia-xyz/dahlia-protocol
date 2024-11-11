// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import { LibString } from "@solady/utils/LibString.sol";

/// @title StringUtilsLib
/// @notice A library for converting uint256 values to string representations.
library StringUtilsLib {
    using LibString for uint256;

    /// @notice Converts a uint256 value to a string representation of percent with 2 decimals.
    /// @param value The uint256 value to convert.
    /// @param value_100_percent value of 100 percent.
    /// @return The string representation of the value in ether with two decimal places.
    function toPercentString(uint256 value, uint256 value_100_percent) public pure returns (string memory) {
        uint256 integerPart = value * 100 / value_100_percent; // Get the whole number part
        uint256 fractionalPart = value * 100 % value_100_percent / (value_100_percent / 100); // Get the fractional part (2 decimal places)
        string memory integerString = integerPart.toString();
        if (fractionalPart == 0) {
            return integerString;
        } else if (fractionalPart % 10 == 0) {
            return string(abi.encodePacked(integerString, ".", (fractionalPart / 10).toString()));
        } else {
            string memory fractionalString = fractionalPart.toString();
            if (fractionalPart < 10) {
                return string(abi.encodePacked(integerString, ".0", fractionalString));
            } else {
                // Include two decimal places
                return string(abi.encodePacked(integerString, ".", fractionalString));
            }
        }
    }
}
