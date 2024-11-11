// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIrm } from "src/irm/interfaces/IIrm.sol";

/// @title IDahliaRegistry
/// @notice Interface for managing addresses and values associated with specific IDs.

interface IDahliaRegistry {
    /// @notice Emitted when adding an IRM to the registry.
    /// @param irm The IRM added to the registry.
    event AllowIrm(IIrm indexed irm);

    /// @notice Emitted when an address is set for a specific ID.
    /// @param setter The address setting the new address.
    /// @param id The ID associated with the new address.
    /// @param newAddress The new address being set.
    event SetAddress(address indexed setter, uint256 indexed id, address newAddress);

    /// @notice Emitted when a value is set for a specific ID.
    /// @param setter The address setting the new value.
    /// @param id The ID associated with the new value.
    /// @param newValue The new value being set.
    event SetValue(address indexed setter, uint256 indexed id, uint256 newValue);

    /// @notice Returns the address associated with a specific ID.
    /// @param id The ID for which to return the associated address.
    /// @return address The address associated with the given ID.
    function getAddress(uint256 id) external view returns (address);

    /// @notice Sets a new address for a specific ID.
    /// @param id The ID for which to set the new address.
    /// @param _addr The new address to associate with the given ID.
    function setAddress(uint256 id, address _addr) external;

    /// @notice Sets a new value for a specific ID.
    /// @param id The ID for which to set the new value.
    /// @param _val The new value to associate with the given ID.
    function setValue(uint256 id, uint256 _val) external;

    /// @notice Returns the value associated with a specific ID, or a default value if not set.
    /// @param id The ID for which to retrieve the associated value.
    /// @param _def The default value to return if no value is set for the given ID.
    /// @return The value associated with the given ID, or the default value if not set.
    function getValue(uint256 id, uint256 _def) external view returns (uint256);

    /// @notice Retrieves the value associated with a specific ID.
    /// @param id The ID for which to retrieve the associated value.
    /// @return The value associated with the given ID.
    function getValue(uint256 id) external view returns (uint256);

    /// @notice Adds an IRM contract address to the registry.
    /// @param irm IRM address.
    function allowIrm(IIrm irm) external;

    /// @notice Checks if an IRM contract address is allowed to be used for the market deployment.
    /// @param irm IRM address.
    function isIrmAllowed(IIrm irm) external view returns (bool);
}
