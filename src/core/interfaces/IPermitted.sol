// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title IPermitted
/// @notice Interface for managing protocol permission
interface IPermitted {
    struct Data {
        address signer;
        address onBehalfOf;
        bool isPermitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Allows setting or revoking permission for another address
    /// @param onBehalfOf The address to be permitted or not permitted
    /// @param newIsPermitted `True` to grant permission, `false` to revoke
    function updatePermission(address onBehalfOf, bool newIsPermitted) external;

    /// @notice Allows setting or revoking permission using an EIP-712 signature
    /// @dev Reverts if the signature has already been used or is invalid
    /// @param data The Permission struct containing the permission details
    /// @param signature The Signature struct containing the EIP-712 signature components
    function updatePermissionWithSig(Data calldata data, bytes memory signature) external;
}
