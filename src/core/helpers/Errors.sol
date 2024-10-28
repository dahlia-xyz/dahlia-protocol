// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors library
 * @author Dahlia
 * @notice Defines protocol error messages.
 */
library Errors {
    /// @notice Insufficient liquidity for borrow, collateral withdrawal, or loan withdrawal.
    error InsufficientLiquidity(uint256 totalBorrowAssets, uint256 totalLendAssets);

    /// @notice Insufficient collateral to borrow.
    error InsufficientCollateral(uint256 borrowedAssets, uint256 maxBorrowAssets);

    /// @notice Trying to liquidate a healthy position.
    error HealthyPositionLiquidation(uint256 ltv, uint256 lltv);

    /// @notice Trying to reallocate a healthy position.
    error HealthyPositionReallocation(uint256 ltv, uint256 rltv);

    /// @notice NotPermitted address calling function `onBehalfOf` another address.
    error NotPermitted();

    /// @notice Zero assets passed as input.
    error ZeroAssets();

    /// @notice Zero address passed as input.
    error ZeroAddress();

    /// @notice Market is not deployed.
    error MarketNotDeployed();

    /// @notice Market is paused.
    error MarketPaused();

    /// @notice Market is paused.
    error CannotChangeMarketStatus();

    /// @notice Market is deprecated.
    error MarketDeprecated();

    /// @notice Trying to deploy an existing market.
    error MarketAlreadyDeployed();

    /// @notice Inconsistent input of assets or shares.
    error InconsistentAssetsOrSharesInput();

    /// @notice Inconsistent markets
    error MarketsDiffer();

    /// @notice Market reallocation ltv is insufficient
    error MarketReallocationLtvInsufficient();

    /// @notice Value is already set.
    error AlreadySet();

    /// @notice LLTV range is not valid.
    error LltvRangeNotValid(uint256, uint256);

    /// @notice Max protocol fee exceeded.
    error MaxProtocolFeeExceeded();

    /// @notice Interest Rate Model not allowed in the registry.
    error IrmNotAllowed();

    /// @notice Liquidation LTV not allowed in the registry.
    error LltvNotAllowed();

    /// @notice Liquidation LTV not allowed in the registry.
    error RltvNotAllowed();

    /// @notice Liquidation LTV not allowed in the registry.
    error OraclePriceBadData();

    /// @notice Signature expired.
    error SignatureExpired();

    /// @notice Invalid signature.
    error InvalidSignature();
}
