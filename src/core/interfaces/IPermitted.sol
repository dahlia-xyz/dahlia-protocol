// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title IPermitted
/// @notice Interface for handling permissions in the protocol
interface IPermitted {
    struct Data {
        address signer;
        address permitted;
        bool isPermitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @dev Emitted when permissions are updated.
    /// @param sender Address of the sender.
    /// @param owner Address of the owner.
    /// @param permitted Address that is permitted.
    /// @param newIsPermitted New permission status.
    event UpdatePermission(address indexed sender, address indexed owner, address indexed permitted, bool newIsPermitted);

    /// @notice Set or revoke permission for an address
    /// @param permitted The address to grant or revoke permission
    /// @param newIsPermitted `True` to allow, `false` to disallow
    function updatePermission(address permitted, bool newIsPermitted) external;

    /// @notice Set or revoke permission using an EIP-712 signature
    /// @dev Fails if the signature is reused or invalid
    /// @param data The permission details
    /// @param signature The EIP-712 signature
    function updatePermissionWithSig(Data calldata data, bytes memory signature) external;
}
