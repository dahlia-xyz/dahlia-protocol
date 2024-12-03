// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIrm } from "src/irm/interfaces/IIrm.sol";

/// @title IDahliaRegistry
/// @notice Interface for managing addresses and values linked to specific IDs.

interface IDahliaRegistry {
    /// @notice Emitted when an IRM is added to the registry.
    /// @param irm The IRM added.
    event AllowIrm(IIrm indexed irm);

    /// @notice Emitted when an IRM is removed from the registry.
    /// @param irm The IRM removed.
    event DisallowIrm(IIrm indexed irm);

    /// @notice Emitted when an address is set for an ID.
    /// @param id The ID linked to the new address.
    /// @param newAddress The new address.
    event SetAddress(uint256 indexed id, address newAddress);

    /// @notice Emitted when a value is set for an ID.
    /// @param id The ID linked to the new value.
    /// @param newValue The new value.
    event SetValue(uint256 indexed id, uint256 newValue);

    /// @notice Get the address linked to an ID.
    /// @param id The ID to check.
    /// @return address The linked address.
    function getAddress(uint256 id) external view returns (address);

    /// @notice Set a new address for an ID.
    /// @param id The ID to update.
    /// @param _addr The new address.
    function setAddress(uint256 id, address _addr) external;

    /// @notice Set a new value for an ID.
    /// @param id The ID to update.
    /// @param _val The new value.
    function setValue(uint256 id, uint256 _val) external;

    /// @notice Get the value linked to an ID, or a default if not set.
    /// @param id The ID to check.
    /// @param _def Default value if none is set.
    /// @return The linked value or default.
    function getValue(uint256 id, uint256 _def) external view returns (uint256);

    /// @notice Get the value linked to an ID.
    /// @param id The ID to check.
    /// @return The linked value.
    function getValue(uint256 id) external view returns (uint256);

    /// @notice Add an IRM address to the registry.
    /// @param irm The IRM address.
    function allowIrm(IIrm irm) external;

    /// @notice Remove an IRM address from the registry.
    /// @param irm The IRM address.
    function disallowIrm(IIrm irm) external;

    /// @notice Check if an IRM address is allowed for market deployment.
    /// @param irm The IRM address.
    /// @return True if allowed, false otherwise.
    function isIrmAllowed(IIrm irm) external view returns (bool);
}
