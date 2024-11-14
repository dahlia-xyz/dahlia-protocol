// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

/// @title IRoycoWrappedVaultFactory
/// @notice Interface for integrating Royco's WrappedVaultFactory with Dahlia markets.
/// @dev Check out https://github.com/roycoprotocol/royco/blob/main/src/WrappedVaultFactory.sol for more details.
interface IRoycoWrappedVaultFactory {
    function wrapVault(IERC4626 vault, address owner, string memory name, uint256 initialFrontendFee) external returns (WrappedVault);

    function isVault(address vault) external returns (bool);
}
