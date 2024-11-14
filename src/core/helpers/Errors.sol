// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors library
 * @notice Contains error messages for the protocol.
 */
library Errors {
    /// @notice Not enough liquidity for borrowing, collateral withdrawal, or loan withdrawal.
    error InsufficientLiquidity(uint256 totalBorrowAssets, uint256 totalLendAssets);

    /// @notice Not enough collateral to borrow.
    error InsufficientCollateral(uint256 borrowedAssets, uint256 maxBorrowAssets);

    /// @notice Can't liquidate a healthy position.
    error HealthyPositionLiquidation(uint256 ltv, uint256 lltv);

    /// @notice Address not permitted to call function on behalf of another.
    error NotPermitted(address sender);

    /// @notice Input assets are zero.
    error ZeroAssets();

    /// @notice Input address is zero.
    error ZeroAddress();

    /// @notice Market hasn't been deployed.
    error MarketNotDeployed();

    /// @notice Market is currently paused.
    error MarketPaused();

    /// @notice Can't change the market status.
    error CannotChangeMarketStatus();

    /// @notice Market is deprecated.
    error MarketDeprecated();

    /// @notice Attempting to deploy a market that already exists.
    error MarketAlreadyDeployed();

    /// @notice Assets or shares input is inconsistent.
    error InconsistentAssetsOrSharesInput();

    /// @notice Markets are inconsistent.
    error MarketsDiffer();

    /// @notice Value has already been set.
    error AlreadySet();

    /// @notice Range provided is not valid.
    error RangeNotValid(uint256, uint256);

    /// @notice Maximum fee has been exceeded.
    error MaxFeeExceeded();

    /// @notice Interest Rate Model isn't allowed in the registry.
    error IrmNotAllowed();

    /// @notice Liquidation LTV is not within the allowed range.
    error LltvNotAllowed();

    /// @notice Liquidation LTV must have only 1 decimal, e.g., 80.1 (80100), not 80.15 (80150).
    error LltvInvalidPrecision();

    /// @notice Liquidation bonus rate isn't allowed.
    error LiquidationBonusRateNotAllowed();

    /// @notice Oracle price data is bad.
    error OraclePriceBadData();

    /// @notice Signature has expired.
    error SignatureExpired();

    /// @notice Signature is invalid.
    error InvalidSignature();
}
