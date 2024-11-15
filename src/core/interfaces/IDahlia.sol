// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIrm } from "src/irm/interfaces/IIrm.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/// @title IDahlia
/// @notice Interface for main Dahlia protocol functions
interface IDahlia {
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

    /// @notice Get user position for a market id and address.
    /// @param id Market id.
    /// @param userAddress User address.
    function getMarketUserPosition(MarketId id, address userAddress) external view returns (MarketUserPosition memory position);

    /// @notice Get max borrowable assets for a user in a market.
    /// @param id Market id.
    /// @param userAddress User address.
    function marketUserMaxBorrows(MarketId id, address userAddress)
        external
        view
        returns (uint256 maxBorrowAssets, uint256 borrowAssets, uint256 collateralPrice);

    /// @notice Get user's loan-to-value ratio for a market.
    /// @param id Market id.
    /// @param userAddress User address.
    function getPositionLTV(MarketId id, address userAddress) external view returns (uint256);

    /// @notice Get user's earned interest for a market.
    /// @param id Market id.
    /// @param userAddress User address.
    /// @return assets number of assets earned as interest
    /// @return shares number of shares earned as interest
    function getPositionInterest(MarketId id, address userAddress) external view returns (uint256 assets, uint256 shares);

    /// @notice Get market parameters.
    /// @param id Market id.
    function getMarket(MarketId id) external view returns (Market memory);

    /// @notice Check if a market is deployed.
    /// @param id Market id.
    function isMarketDeployed(MarketId id) external view returns (bool);

    /// @notice Pause a market.
    /// @param id Market id.
    function pauseMarket(MarketId id) external;

    /// @notice Unpause a market.
    /// @param id Market id.
    function unpauseMarket(MarketId id) external;

    /// @notice Update liquidation bonus rate for the market.
    /// @param id Market id.
    /// @param liquidationBonusRate New liquidation bonus rate, precision: Constants.LLTV_100_PERCENT.
    function updateLiquidationBonusRate(MarketId id, uint256 liquidationBonusRate) external;

    /// @notice Deprecate a market.
    /// @param id Market id.
    function deprecateMarket(MarketId id) external;

    /// @notice Get protocol fee recipient address.
    function protocolFeeRecipient() external view returns (address);

    /// @notice Set LLTV range for market creation.
    /// @param range Min-max range.
    function setLltvRange(RateRange memory range) external;

    /// @notice Set liquidation bonus rate range for market creation.
    /// @param range Min-max range.
    function setLiquidationBonusRateRange(RateRange memory range) external;

    /// @notice Set protocol fee recipient for all markets.
    /// @param newProtocolFeeRecipient New protocol fee recipient address.
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external;

    /// @notice Set reserve fee recipient for all markets.
    /// @param newReserveFeeRecipient New reserve fee recipient address.
    function setReserveFeeRecipient(address newReserveFeeRecipient) external;

    /// @notice Sets flash loan fee.
    /// @param newFee New flash loan fee.
    function setFlashLoanFeeRate(uint24 newFee) external;

    /// @notice Configuration parameters for deploying a new market.
    /// @param loanToken The address of the loan token.
    /// @param collateralToken The address of the collateral token.
    /// @param oracle The oracle contract for price feeds.
    /// @param irm The interest rate model contract.
    /// @param lltv Liquidation loan-to-value ratio for the market.
    /// @param liquidationBonusRate Bonus rate for liquidations.
    /// @param owner The owner of the deployed market.
    struct MarketConfig {
        address loanToken;
        address collateralToken;
        IDahliaOracle oracle;
        IIrm irm;
        uint256 lltv;
        uint256 liquidationBonusRate;
        /// @dev Owner of the deployed market
        address owner;
    }

    /// @notice Deploys a new market with the given parameters and returns its id.
    /// @param marketConfig The parameters of the market.
    function deployMarket(MarketConfig memory marketConfig) external returns (MarketId id);

    /// @notice Set new protocol fee for a market.
    /// @param id Market id.
    /// @param newFee New fee, precision: Constants.FEE_PRECISION.
    function setProtocolFeeRate(MarketId id, uint32 newFee) external;

    /// @notice Set new reserve fee for a market.
    /// @param id Market id.
    /// @param newFee New fee, precision: Constants.FEE_PRECISION.
    function setReserveFeeRate(MarketId id, uint32 newFee) external;

    /// @notice Lend `assets` on behalf of a user, with optional callback.
    /// @dev Should be called via wrapped vault.
    /// @param id Market id.
    /// @param assets Amount of assets to lend.
    /// @param onBehalfOf Owner of the increased lend position.
    /// @return sharesSupplied Amount of shares minted.
    function lend(MarketId id, uint256 assets, address onBehalfOf) external returns (uint256 sharesSupplied);

    /// @notice Withdraw `assets` by `shares` on behalf of a user, sending to a receiver.
    /// @dev Should be invoked through a wrapped vault.
    /// @param id Market id.
    /// @param shares Amount of shares to burn.
    /// @param onBehalfOf Owner of the lend position.
    /// @param receiver Address receiving the assets.
    /// @return assetsWithdrawn Amount of assets withdrawn.
    function withdraw(MarketId id, uint256 shares, address onBehalfOf, address receiver) external payable returns (uint256 assetsWithdrawn);

    /// @notice Claim accrued interest for the position.
    /// @dev Should be invoked through a wrapped vault.
    /// @param id Market id.
    /// @param onBehalfOf Owner of the lend position.
    /// @param receiver Address receiving the assets.
    function claimInterest(MarketId id, address onBehalfOf, address receiver) external payable returns (uint256 assets);

    /// @notice Estimates the interest rate after depositing a specified amount of assets.
    /// @dev Should be invoked through a wrapped vault.
    /// @param id Market id.
    /// @param assets The amount of assets intended for deposit.
    /// @return ratePerSec The projected interest rate per second post-deposit.
    function previewLendRateAfterDeposit(MarketId id, uint256 assets) external view returns (uint256 ratePerSec);

    /// @notice Borrow `assets` or `shares` on behalf of a user, sending to a receiver.
    /// @dev Either `assets` or `shares` must be zero.
    /// @param id Market id.
    /// @param assets Amount of assets to borrow.
    /// @param shares Amount of shares to mint.
    /// @param onBehalfOf Address owning the increased borrow position.
    /// @param receiver Address receiving the borrowed assets.
    /// @return assetsBorrowed Amount of assets borrowed.
    /// @return sharesBorrowed Amount of shares minted.
    function borrow(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, address receiver)
        external
        returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    /// @notice Supply `collateralAssets` and borrow `borrowAssets` on behalf of a user, sending borrowed assets to a receiver.
    /// @dev Both `collateralAssets` and `borrowAssets` must not be zero.
    /// @param id Market id.
    /// @param collateralAssets Amount of assets for collateral.
    /// @param borrowAssets Amount of assets to borrow.
    /// @param onBehalfOf Address owning the increased borrow position.
    /// @param receiver Address receiving the borrowed assets.
    /// @return borrowedAssets Amount of assets borrowed.
    /// @return borrowedShares Amount of shares minted.
    function supplyAndBorrow(MarketId id, uint256 collateralAssets, uint256 borrowAssets, address onBehalfOf, address receiver)
        external
        returns (uint256 borrowedAssets, uint256 borrowedShares);

    /// @notice Repay borrowed assets or shares on behalf of a user and withdraw collateral to a receiver.
    /// @dev Either `repayAssets` or `repayShares` must be zero.
    /// @param id Market id.
    /// @param collateralAssets Amount of assets for collateral.
    /// @param repayAssets Amount of borrow assets to repay.
    /// @param repayShares Amount of borrow shares to burn.
    /// @param onBehalfOf Owner of the debt position.
    /// @param receiver Address receiving the withdrawn collateral.
    /// @return repaidAssets Amount of assets repaid.
    /// @return repaidShares Amount of shares burned.
    function repayAndWithdraw(MarketId id, uint256 collateralAssets, uint256 repayAssets, uint256 repayShares, address onBehalfOf, address receiver)
        external
        returns (uint256 repaidAssets, uint256 repaidShares);

    /// @notice Repay `assets` or `shares` on behalf of a user, with optional callback.
    /// @dev Either `assets` or `shares` must be zero.
    /// @param id Market id.
    /// @param assets Amount of assets to repay.
    /// @param shares Amount of shares to burn.
    /// @param onBehalfOf Owner of the debt position.
    /// @param callbackData Data for `onDahliaRepay` callback. Empty if not needed.
    /// @return assetsRepaid Amount of assets repaid.
    /// @return sharesRepaid Amount of shares burned.
    function repay(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256 assetsRepaid, uint256 sharesRepaid);

    /// TODO review comment
    /// @notice Liquidate a debt position by repaying shares or seizing collateral, with optional callback.
    /// @param id Market id.
    /// @param borrower Borrower's address.
    /// @param callbackData Data for `onDahliaLiquidate` callback. Empty if not needed.
    /// @return collateralSeized Amount of collateral seized.
    /// @return assetsRepaid Amount of assets repaid.
    /// @return sharesRepaid Amount of shares repaid.
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

    /// @notice Withdraw collateral on behalf of a user, sending to a receiver.
    /// @param id Market id.
    /// @param assets Amount of collateral to withdraw.
    /// @param onBehalfOf Owner of the debt position.
    /// @param receiver Address receiving the collateral assets.
    function withdrawCollateral(MarketId id, uint256 assets, address onBehalfOf, address receiver) external;

    /// @notice Execute a flash loan.
    /// @param token Borrowed token address.
    /// @param assets Amount to borrow.
    /// @param data Data for `onDahliaFlashLoan` callback.
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    /// @notice Accrue interest for market parameters.
    /// @param id Market id.
    function accrueMarketInterest(MarketId id) external;
}
