// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Types} from "src/core/types/Types.sol";

/// @title IMarketStorage
/// @notice Interface for the market storage functions
interface IMarketStorage {
    // TODO
    // /// @notice Returns the market config for a given market ID.
    // /// @param marketId The unique market id.
    // function marketConfigs(Types.MarketId marketId) external view returns (Types.MarketConfig memory);

    // /// @notice Returns the market state for a given market ID
    // /// @param marketId The unique identifier of the market.
    // function marketState(Types.MarketId marketId) external view returns (Types.MarketState memory);

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function getMarketUserPosition(Types.MarketId marketId, address userAddress)
        external
        view
        returns (Types.MarketUserPosition memory position);

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function marketUserMaxBorrows(Types.MarketId marketId, address userAddress)
        external
        view
        returns (uint256 maxBorrowAssets, uint256 borrowAssets, uint256 collateralPrice);

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function getPositionLTV(Types.MarketId marketId, address userAddress) external view returns (uint256);

    /// @notice Returns market params.
    /// @param marketId The unique market id.
    function getMarket(Types.MarketId marketId) external view returns (Types.Market memory);

    /// @notice Checks existence of the market for the given market ID.
    /// @param marketId The unique market id.
    function isMarketDeployed(Types.MarketId marketId) external view returns (bool);

    /// @notice Pause market.
    /// @param id of the market.
    function pauseMarket(Types.MarketId id) external;

    /// @notice UnpPause market.
    /// @param id of the market.
    function unpauseMarket(Types.MarketId id) external;

    /// @notice Update liquidationBonusRate and reallocationBonusRate for given market.
    /// @param id of the market.
    /// @param liquidationBonusRate The new liquidationBonusRate where 100% is LLTV_100_PERCENT
    /// @param reallocationBonusRate The new reallocationBonusRate where 100% is LLTV_100_PERCENT.
    function updateMarketBonusRates(Types.MarketId id, uint256 liquidationBonusRate, uint256 reallocationBonusRate)
        external;

    /// @notice Update admin for given market.
    /// @param id of the market.
    /// @param admin The new admin. 0 address mean no admin, but owner still can control
    function updateMarketAdmin(Types.MarketId id, address admin) external;

    /// @notice Deprecate market.
    /// @param id of the market.
    function deprecateMarket(Types.MarketId id) external;

    /// @notice Returns the last market state for given market parameters
    /// @param id of the market
    function getLastMarketState(Types.MarketId id)
        external
        view
        returns (
            uint256 totalLendAssets,
            uint256 totalLendShares,
            uint256 totalBorrowAssets,
            uint256 totalBorrowShares,
            uint256 fullUtilizationRate,
            uint256 ratePerSec
        );
}

/// @title IDahlia
/// @notice Interface for the main Dahlia protocol functions
interface IDahlia is IMarketStorage {
    /// @notice Returns the protocol fee recipient address
    function protocolFeeRecipient() external view returns (address);

    /// @notice Returns the proxy factory address
    function proxyFactory() external view returns (address);

    /// @notice Sets a possible LLTV range for market creation.
    /// @param range min max range.
    function setLltvRange(Types.RateRange memory range) external;

    /// @notice Sets a possible liquidation bonus rate range for market creation.
    /// @param range min max range.
    function setLiquidationBonusRateRange(Types.RateRange memory range) external;

    /// @notice Sets the protocol fee recipient address for all markets
    /// @param newProtocolFeeRecipient The new protocol fee recipient address
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external;

    /// @notice Sets the protocol fee recipient address for all markets
    /// @param newReserveFeeRecipient The new protocol fee recipient address
    function setReserveFeeRecipient(address newReserveFeeRecipient) external;

    /// @notice Deploys a new market with the given parameters and returns its id.
    /// @param marketConfig The parameters of the market.
    /// @param data Additional data for market creation.
    function deployMarket(Types.MarketConfig memory marketConfig, bytes calldata data)
        external
        returns (Types.MarketId id);

    /// @notice Sets a new protocol fee for a given market.
    /// @param id of the market.
    /// @param newFee The new fee, scaled by WAD.
    function setProtocolFeeRate(Types.MarketId id, uint32 newFee) external;

    /// @notice Sets a new reserve fee for a given market.
    /// @param id of the market.
    /// @param newFee The new fee, scaled by WAD.
    function setReserveFeeRate(Types.MarketId id, uint32 newFee) external;

    /// @notice Lends `assets` on behalf of a user, with an optional callback.
    /// @dev This function designed to be called by ERC4626Proxy contract.
    /// @param id of the market.
    /// @param assets The amount of assets to lend.
    /// @param onBehalfOf The address that will own the increased lend position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaLend` callback. Pass empty data if not needed.
    /// @return sharesSupplied The amount of shares minted.
    function lend(Types.MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256 sharesSupplied);

    /// @notice Withdraws `assets` by `shares` on behalf of a user and sends the assets to a receiver.
    /// @dev This function designed to be called by ERC4626Proxy contract.
    /// @param id of the market.
    /// @param shares The amount of shares to burn.
    /// @param onBehalfOf The address of the owner of the supply position.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @return assetsWithdrawn The amount of assets withdrawn.
    function withdraw(Types.MarketId id, uint256 shares, address onBehalfOf, address receiver)
        external
        returns (uint256 assetsWithdrawn);

    /// @notice Borrows `assets` or `shares` on behalf of a user and sends the assets to a receiver.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to mint.
    /// @param onBehalfOf The address that will own the increased borrow position.
    /// @param receiver The address that will receive the borrowed assets.
    /// @return assetsBorrowed The amount of assets borrowed.
    /// @return sharesBorrowed The amount of shares minted.
    function borrow(Types.MarketId id, uint256 assets, uint256 shares, address onBehalfOf, address receiver)
        external
        returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    /// @notice Supplies collateral and borrows `assets` or `shares` on behalf of a user and sends the assets to a receiver.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param collateralAssets The amount of assets for collateral.
    /// @param borrowAssets The amount of assets to borrow.
    /// @param onBehalfOf The address that will own the increased borrow position.
    /// @param receiver The address that will receive the borrowed assets.
    /// @return borrowedAssets The amount of assets borrowed.
    /// @return borrowedShares The amount of shares minted.
    function supplyAndBorrow(
        Types.MarketId id,
        uint256 collateralAssets,
        uint256 borrowAssets,
        address onBehalfOf,
        address receiver
    ) external returns (uint256 borrowedAssets, uint256 borrowedShares);

    /// @notice Repays  borrowed `assets` or `shares` on behalf of a user and and withdraw collateral to a receiver.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param collateralAssets The amount of assets for collateral.
    /// @param repayAssets The amount of assets to repay.
    /// @param repayShares The amount of shares to burn.
    /// @param onBehalfOf The address that will own the increased borrow position.
    /// @param receiver The address that will receive the borrowed assets.
    /// @return repaidAssets The amount of shares minted.
    /// @return repaidShares The amount of shares minted.
    function repayAndWithdraw(
        Types.MarketId id,
        uint256 collateralAssets,
        uint256 repayAssets,
        uint256 repayShares,
        address onBehalfOf,
        address receiver
    ) external returns (uint256 repaidAssets, uint256 repaidShares);

    /// @notice Repays `assets` or `shares` on behalf of a user, with an optional callback.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param assets The amount of assets to repay.
    /// @param shares The amount of shares to burn.
    /// @param onBehalfOf The address of the owner of the debt position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaRepay` callback. Pass empty data if not needed.
    /// @return assetsRepaid The amount of assets repaid.
    /// @return sharesRepaid The amount of shares burned.
    function repay(Types.MarketId id, uint256 assets, uint256 shares, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256 assetsRepaid, uint256 sharesRepaid);

    /// @notice Liquidates a debt position by repaying shares or seizing collateral, with an optional callback.
    /// @param id of the market.
    /// @param borrower The address of the borrower.
    /// @param callbackData Arbitrary data to pass to the `onDahliaLiquidate` callback. Pass empty data if not needed.
    /// @return collateralSeized The amount of assets seized.
    /// @return assetsRepaid The amount of assets repaid.
    /// @return sharesRepaid The amount of shares repaid.
    function liquidate(Types.MarketId id, address borrower, bytes calldata callbackData)
        external
        returns (uint256 collateralSeized, uint256 assetsRepaid, uint256 sharesRepaid);

    /// @notice Reallocates a debt position.
    /// @param marketId id of the market from.
    /// @param marketId id of the market to.
    /// @param borrower The address of the borrower.
    /// @return reallocatedAssets The amount of reallocated assets.
    /// @return reallocatedShares The amount of reallocated shares.
    /// @return reallocatedCollateral The amount of reallocated collateral.
    /// @return bonusCollateral The amount of collateral bonus for reallocator.
    function reallocate(Types.MarketId marketId, Types.MarketId marketIdTo, address borrower)
        external
        returns (
            uint256 reallocatedAssets,
            uint256 reallocatedShares,
            uint256 reallocatedCollateral,
            uint256 bonusCollateral
        );

    /// @notice Supplies collateral on behalf of a user, with an optional callback.
    /// @param id of the market.
    /// @param assets The amount of collateral to supply.
    /// @param onBehalfOf The address that will own the increased collateral position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaSupplyCollateral` callback.
    ///        Pass empty data if not needed.
    function supplyCollateral(Types.MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData)
        external;

    /// @notice Withdraws collateral on behalf of a user and sends the assets to a receiver.
    /// @param id of the market.
    /// @param assets The amount of collateral to withdraw.
    /// @param onBehalfOf The address of the owner of the collateral position.
    /// @param receiver The address that will receive the collateral assets.
    function withdrawCollateral(Types.MarketId id, uint256 assets, address onBehalfOf, address receiver) external;

    /// @notice Executes a flash loan.
    /// @param token The token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onDahliaFlashLoan` callback.
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    /// @notice Accrues interest for the given market parameters.
    /// @param id of the market.
    function accrueMarketInterest(Types.MarketId id) external;
}
