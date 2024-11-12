// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIrm } from "src/irm/interfaces/IIrm.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/// @title IMarketStorage
/// @notice Interface for the market storage functions
interface IMarketStorage {
    type MarketId is uint32;

    enum MarketStatus {
        None,
        Active,
        Paused,
        Deprecated
    }

    struct RateRange {
        uint24 min;
        uint24 max;
    }

    struct Market {
        // --- 28 bytes
        MarketId id; // 4 bytes
        uint24 lltv; // 3 bytes
        MarketStatus status; // 1 byte
        address loanToken; // 20 bytes
        // --- 32 bytes
        address collateralToken; // 20 bytes
        uint48 updatedAt; // 6 bytes //
            // https://doc.confluxnetwork.org/docs/general/build/smart-contracts/gas-optimization/timestamps-and-blocknumbers#understanding-the-optimization
        uint24 protocolFeeRate; // 3 bytes // taken from interest
        uint24 reserveFeeRate; // 3 bytes // taken from interest
        // --- 31 bytes
        IDahliaOracle oracle; // 20 bytes
        uint64 fullUtilizationRate; // 3 bytes
        uint64 ratePerSec; // 8 bytes // store refreshed rate per second
        // --- 23 bytes
        IIrm irm; // 20 bytes
        uint24 liquidationBonusRate; // 3 bytes
        // --- 20 bytes
        IWrappedVault vault; // 20 bytes
        // --- having all 256 bytes at the end make deployment size smaller
        uint256 totalLendAssets; // 32 bytes
        uint256 totalLendShares; // 32 bytes
        uint256 totalBorrowAssets; // 32 bytes
        uint256 totalBorrowShares; // 32 bytes
    }

    struct MarketUserPosition {
        uint128 lendShares;
        uint128 lendAssets; // store user initial lend assets
        uint128 borrowShares;
        uint128 collateral;
    }

    struct MarketData {
        Market market;
        mapping(address => MarketUserPosition) userPositions;
    }

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function getMarketUserPosition(MarketId marketId, address userAddress) external view returns (MarketUserPosition memory position);

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function marketUserMaxBorrows(MarketId marketId, address userAddress)
        external
        view
        returns (uint256 maxBorrowAssets, uint256 borrowAssets, uint256 collateralPrice);

    /// @notice Returns the user position for a given market ID and address.
    /// @param marketId The unique market id.
    /// @param userAddress User address.
    function getPositionLTV(MarketId marketId, address userAddress) external view returns (uint256);

    /// @notice Returns market params.
    /// @param marketId The unique market id.
    function getMarket(MarketId marketId) external view returns (Market memory);

    /// @notice Checks existence of the market for the given market ID.
    /// @param marketId The unique market id.
    function isMarketDeployed(MarketId marketId) external view returns (bool);

    /// @notice Pause market.
    /// @param id of the market.
    function pauseMarket(MarketId id) external;

    /// @notice UnpPause market.
    /// @param id of the market.
    function unpauseMarket(MarketId id) external;

    /// @notice Update liquidationBonusRate for given market.
    /// @param id of the market.
    /// @param liquidationBonusRate The new liquidationBonusRate where 100% is LLTV_100_PERCENT
    function updateMarketBonusRates(MarketId id, uint256 liquidationBonusRate) external;

    /// @notice Deprecate market.
    /// @param id of the market.
    function deprecateMarket(MarketId id) external;
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
    function setLltvRange(RateRange memory range) external;

    /// @notice Sets a possible liquidation bonus rate range for market creation.
    /// @param range min max range.
    function setLiquidationBonusRateRange(RateRange memory range) external;

    /// @notice Sets the protocol fee recipient address for all markets
    /// @param newProtocolFeeRecipient The new protocol fee recipient address
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external;

    /// @notice Sets the protocol fee recipient address for all markets
    /// @param newReserveFeeRecipient The new protocol fee recipient address
    function setReserveFeeRecipient(address newReserveFeeRecipient) external;

    /// @notice Sets a new flash loan fee.
    /// @param newFee The new fee.
    function setFlashLoanFeeRate(uint24 newFee) external;

    /// @notice Deploys a new market with the given parameters and returns its id.
    /// @param @param loanToken The address of the loan token.
    struct MarketConfig {
        address loanToken;
        address collateralToken;
        IDahliaOracle oracle;
        IIrm irm;
        uint256 lltv;
        uint256 liquidationBonusRate;
        /// @dev owner of the deployed market
        address owner;
    }

    /// @notice Deploys a new market with the given parameters and returns its id.
    /// @param marketConfig The parameters of the market.
    function deployMarket(MarketConfig memory marketConfig) external returns (MarketId id);

    /// @notice Sets a new protocol fee for a given market.
    /// @param id of the market.
    /// @param newFee The new fee.
    function setProtocolFeeRate(MarketId id, uint32 newFee) external;

    /// @notice Sets a new reserve fee for a given market.
    /// @param id of the market.
    /// @param newFee The new fee.
    function setReserveFeeRate(MarketId id, uint32 newFee) external;

    /// @notice Lends `assets` on behalf of a user, with an optional callback.
    /// @dev This function designed to be called by ERC4626Proxy contract.
    /// @param id of the market.
    /// @param assets The amount of assets to lend.
    /// @param onBehalfOf The address that will own the increased lend position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaLend` callback. Pass empty data if not needed.
    /// @return sharesSupplied The amount of shares minted.
    function lend(MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData) external returns (uint256 sharesSupplied);

    /// @notice Withdraws `assets` by `shares` on behalf of a user and sends the assets to a receiver.
    /// @dev This function designed to be called by ERC4626Proxy contract.
    /// @param id of the market.
    /// @param shares The amount of shares to burn.
    /// @param onBehalfOf The address of the owner of the supply position.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @return assetsWithdrawn The amount of assets withdrawn.
    function withdraw(MarketId id, uint256 shares, address onBehalfOf, address receiver) external returns (uint256 assetsWithdrawn);

    function claimInterest(MarketId id, address onBehalfOf, address receiver) external returns (uint256 assets);

    function previewLendRateAfterDeposit(MarketId id, uint256 assets) external view returns (uint256 ratePerSec);

    /// @notice Borrows `assets` or `shares` on behalf of a user and sends the assets to a receiver.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to mint.
    /// @param onBehalfOf The address that will own the increased borrow position.
    /// @param receiver The address that will receive the borrowed assets.
    /// @return assetsBorrowed The amount of assets borrowed.
    /// @return sharesBorrowed The amount of shares minted.
    function borrow(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, address receiver)
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
    function supplyAndBorrow(MarketId id, uint256 collateralAssets, uint256 borrowAssets, address onBehalfOf, address receiver)
        external
        returns (uint256 borrowedAssets, uint256 borrowedShares);

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
    function repayAndWithdraw(MarketId id, uint256 collateralAssets, uint256 repayAssets, uint256 repayShares, address onBehalfOf, address receiver)
        external
        returns (uint256 repaidAssets, uint256 repaidShares);

    /// @notice Repays `assets` or `shares` on behalf of a user, with an optional callback.
    /// @dev either the `assets` or the `shares` must be set to zero.
    /// @param id of the market.
    /// @param assets The amount of assets to repay.
    /// @param shares The amount of shares to burn.
    /// @param onBehalfOf The address of the owner of the debt position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaRepay` callback. Pass empty data if not needed.
    /// @return assetsRepaid The amount of assets repaid.
    /// @return sharesRepaid The amount of shares burned.
    function repay(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256 assetsRepaid, uint256 sharesRepaid);

    /// @notice Liquidates a debt position by repaying shares or seizing collateral, with an optional callback.
    /// @param id of the market.
    /// @param borrower The address of the borrower.
    /// @param callbackData Arbitrary data to pass to the `onDahliaLiquidate` callback. Pass empty data if not needed.
    /// @return collateralSeized The amount of assets seized.
    /// @return assetsRepaid The amount of assets repaid.
    /// @return sharesRepaid The amount of shares repaid.
    function liquidate(MarketId id, address borrower, bytes calldata callbackData)
        external
        returns (uint256 collateralSeized, uint256 assetsRepaid, uint256 sharesRepaid);

    /// @notice Supplies collateral on behalf of a user, with an optional callback.
    /// @param id of the market.
    /// @param assets The amount of collateral to supply.
    /// @param onBehalfOf The address that will own the increased collateral position.
    /// @param callbackData Arbitrary data to pass to the `onDahliaSupplyCollateral` callback.
    ///        Pass empty data if not needed.
    function supplyCollateral(MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData) external;

    /// @notice Withdraws collateral on behalf of a user and sends the assets to a receiver.
    /// @param id of the market.
    /// @param assets The amount of collateral to withdraw.
    /// @param onBehalfOf The address of the owner of the collateral position.
    /// @param receiver The address that will receive the collateral assets.
    function withdrawCollateral(MarketId id, uint256 assets, address onBehalfOf, address receiver) external;

    /// @notice Executes a flash loan.
    /// @param token The token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onDahliaFlashLoan` callback.
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    /// @notice Accrues interest for the given market parameters.
    /// @param id of the market.
    function accrueMarketInterest(MarketId id) external;
}
