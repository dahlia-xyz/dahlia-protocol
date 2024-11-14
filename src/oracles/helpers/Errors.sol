// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title Errors library
library Errors {
    /// @dev Thrown when a negative value is encountered.
    error NegativeAnswer(int256 value);

    /// @dev Thrown when a zero address is provided.
    error ZeroAddress();
}
