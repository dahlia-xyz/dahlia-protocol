// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626Proxy} from "src/core/contracts/ERC4626Proxy.sol";
import {IERC4626ProxyFactory} from "src/core/interfaces/IERC4626ProxyFactory.sol";
import {Types} from "src/core/types/Types.sol";

/// @title ERC4626ProxyFactory
/// @notice Factory to deploy ERC4626Proxy vaults.
contract ERC4626ProxyFactory is IERC4626ProxyFactory {
    /// @inheritdoc IERC4626ProxyFactory
    function deployProxy(Types.MarketConfig memory marketConfig, Types.MarketId id) external returns (IERC4626) {
        return new ERC4626Proxy(msg.sender, marketConfig, id);
    }
}
