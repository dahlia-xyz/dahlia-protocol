// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";

/// @title IDahliaProvider
/// @notice Interface for the Dahlia integrations with external contracts.
interface IDahliaProvider {
    /// @notice Function to be called when a new market is deployed.
    /// @param id The unique market id.
    /// @param marketProxy The ERC4626Proxy vault for the newly deployed market.
    /// @param sender The market deployer address.
    /// @param data Additional arbitrary data for future use.
    function onMarketDeployed(IDahlia.MarketId id, IERC4626 marketProxy, address sender, bytes calldata data)
        external;
}
