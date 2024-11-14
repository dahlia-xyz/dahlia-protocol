// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Uniswap V3 Single TWAP Oracle Interface
/// @notice Interface for interacting with the Uniswap V3 TWAP oracle
interface IUniswapV3SingleTwapOracle is IERC165 {
    /// @notice Get the precision used for TWAP calculations
    /// @return The precision as a uint128
    function TWAP_PRECISION() external view returns (uint128);

    /// @notice Get the base token address for the Uniswap V3 TWAP
    /// @return The base token address
    function UNISWAP_V3_TWAP_BASE_TOKEN() external view returns (address);

    /// @notice Get the quote token address for the Uniswap V3 TWAP
    /// @return The quote token address
    function UNISWAP_V3_TWAP_QUOTE_TOKEN() external view returns (address);

    /// @notice Get the static oracle address used in Uniswap V3
    /// @return The static oracle address
    function UNISWAP_STATIC_ORACLE_ADDRESS() external view returns (address);

    /// @notice Get the Uniswap V3 pair address
    /// @return The pair address
    function UNI_V3_PAIR_ADDRESS() external view returns (address);

    /// @notice Get the current TWAP duration
    /// @return The TWAP duration in seconds
    function twapDuration() external view returns (uint32);

    /// @notice Set a new TWAP duration for the Uniswap V3 TWAP oracle
    /// @dev Only callable by the timelock address
    /// @param _newTwapDuration The new TWAP duration in seconds
    function setTwapDuration(uint32 _newTwapDuration) external;
}
