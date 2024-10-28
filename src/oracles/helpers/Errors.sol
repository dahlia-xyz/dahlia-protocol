// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors library
 * @author Dahlia
 * @notice Defines oracle error messages.
 */
library Errors {
    /// @notice Negative answer.
    error NegativeAnswer(int256 value);

    /// @notice Zero address passed as input.
    error ZeroAddress();
}
