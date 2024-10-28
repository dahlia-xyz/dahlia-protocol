// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWrappedVault} from "@royco/interfaces/IWrappedVault.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {IDahliaProvider} from "src/core/interfaces/IDahliaProvider.sol";
import {IDahliaRegistry} from "src/core/interfaces/IDahliaRegistry.sol";
import {IRoycoWrappedVaultFactory} from "src/core/interfaces/IRoycoWrappedVaultFactory.sol";
import {Types} from "src/core/types/Types.sol";

/// @title DahliaProvider
contract DahliaProvider is IDahliaProvider {
    event IncentivizedVaultCreated(IWrappedVault indexed vault, Types.MarketId indexed marketId);

    IDahliaRegistry public immutable dahliaRegistry;

    constructor(address dahliaRegistry_) {
        dahliaRegistry = IDahliaRegistry(dahliaRegistry_);
    }

    /// @inheritdoc IDahliaProvider
    function onMarketDeployed(Types.MarketId id, IERC4626 marketProxy, address sender, bytes calldata) external {
        uint256 fee = dahliaRegistry.getValue(Constants.VALUE_ID_ROYCO_ERC4626I_FACTORY_MIN_INITIAL_FRONTEND_FEE);
        IRoycoWrappedVaultFactory roycoFactory =
            IRoycoWrappedVaultFactory(dahliaRegistry.getAddress(Constants.ADDRESS_ID_ROYCO_ERC4626I_FACTORY));
        IWrappedVault roycoIncentivizedVault = roycoFactory.wrapVault(marketProxy, sender, marketProxy.name(), fee);
        emit IncentivizedVaultCreated(roycoIncentivizedVault, id);
    }
}
