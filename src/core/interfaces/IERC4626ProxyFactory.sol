// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Types} from "src/core/types/Types.sol";

/// @title IERC4626ProxyFactory
/// @notice Interface for creating ERC4626Proxy vaults that plug into the Dahlia markets.
interface IERC4626ProxyFactory {
    /// @notice Deploys a new ERC4626Proxy vault for for the market.
    /// @param marketConfig The market parameters.
    /// @param id The unique market id.
    /// @return address The address of the deployed vault.
    function deployProxy(Types.MarketConfig memory marketConfig, Types.MarketId id) external returns (IERC4626);
}
