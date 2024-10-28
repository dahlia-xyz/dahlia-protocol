// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWrappedVault} from "@royco/interfaces/IWrappedVault.sol";

/// @title IRoycoWrappedVaultFactory
/// @notice Interface for Royco's WrappedVaultFactory integration with Dahlia markets.
/// @dev see royco/src/WrappedVaultFactory.sol
interface IRoycoWrappedVaultFactory {
    function wrapVault(IERC4626 vault, address owner, string memory name, uint256 initialFrontendFee)
        external
        returns (IWrappedVault);

    function isVault(address vault) external returns (bool);
}
