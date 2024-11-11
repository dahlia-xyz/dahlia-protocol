// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/**
 * @title Events library
 * @author Dahlia
 * @notice Defines protocol events.
 */
library Events {
    /// @notice Emitted when setting a new protocol fee.
    /// @param id The market id.
    /// @param newFee The new fee.
    event SetProtocolFeeRate(IDahlia.MarketId indexed id, uint256 newFee);

    /// @notice Emitted when setting a new reserve fee.
    /// @param id The market id.
    /// @param newFee The new fee.
    event SetReserveFeeRate(IDahlia.MarketId indexed id, uint256 newFee);

    /// @notice Emitted when setting a new protocol fee recipient.
    /// @param newProtocolFeeRecipient The new protocol fee recipient.
    event SetProtocolFeeRecipient(address indexed newProtocolFeeRecipient);

    /// @notice Emitted when setting a new reserve fee recipient.
    /// @param newReserveFeeRecipient The new reserve fee recipient.
    event SetReserveFeeRecipient(address indexed newReserveFeeRecipient);

    /// @notice Emitted when setting a new flash loan fee.
    /// @param newFee The new fee.
    event SetFlashLoanFeeRate(uint256 newFee);

    /// @notice Emitted when allowing an LLTV range.
    /// @param minLltv The min LLTV.
    /// @param maxLltv The max LLTV.
    event SetLLTVRange(uint256 minLltv, uint256 maxLltv);

    /// @notice Emitted when allowing an liquidation bonus rate range.
    /// @param minLltv The min liquidation bonus rate.
    /// @param maxLltv The max liquidation bonus rate.
    event SetLiquidationBonusRateRange(uint256 minLltv, uint256 maxLltv);

    /// @notice Emitted when market status changed.
    /// @param from previous status.
    /// @param to new status.
    event MarketStatusChanged(IDahlia.MarketStatus from, IDahlia.MarketStatus to);

    /// @notice Emitted when market bonus rate changed.
    /// @param liquidationBonusRate The new liquidation bonus rate.
    /// @param reallocationBonusRate The new reallocation bonus rate.
    event MarketBonusRatesChanged(uint256 liquidationBonusRate, uint256 reallocationBonusRate);

    /// @notice Emitted when deploying a market.
    /// @param id The market id.
    /// @param vault The vault address.
    /// @param marketConfig The market parameters.
    event DeployMarket(IDahlia.MarketId indexed id, IWrappedVault indexed vault, IDahlia.MarketConfig marketConfig);

    /// @notice Emitted when setting an authorization.
    /// @param sender The sender.
    /// @param signer The signer address.
    /// @param onBehalfOf The permitted address.
    /// @param newIsPermitted The new authorization status.
    event updatePermission(address indexed sender, address indexed signer, address indexed onBehalfOf, bool newIsPermitted);

    /// @notice Emitted when collateral is supplied.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner on behalf of whom the collateral is supplied.
    /// @param assets The amount of supplied assets.
    event SupplyCollateral(IDahlia.MarketId indexed id, address indexed caller, address indexed onBehalfOf, uint256 assets);

    /// @notice Emitted when collateral is withdrawn.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner on behalf of whom the collateral is withdrawn.
    /// @param receiver The owner of the modified position.
    /// @param assets The amount of assets withdrawn.
    event WithdrawCollateral(IDahlia.MarketId indexed id, address caller, address indexed onBehalfOf, address indexed receiver, uint256 assets);

    /// @notice Emitted on supply of assets.
    /// @dev `protocolFeeRecipient` receives some shares during interest accrual without any supply event emitted.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner of the modified position.
    /// @param assets The amount of assets supplied.
    /// @param shares The amount of shares minted.
    event Lend(IDahlia.MarketId indexed id, address indexed caller, address indexed onBehalfOf, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal of assets.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner of the modified position.
    /// @param receiver The address that received the withdrawn assets.
    /// @param assets The amount of assets withdrawn.
    /// @param shares The amount of shares burned.
    event Withdraw(IDahlia.MarketId indexed id, address caller, address indexed onBehalfOf, address indexed receiver, uint256 assets, uint256 shares);

    /// @notice Emitted on borrow of assets.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner of the modified position.
    /// @param receiver The address that received the borrowed assets.
    /// @param assets The amount of assets borrowed.
    /// @param shares The amount of shares minted.
    event DahliaBorrow(IDahlia.MarketId indexed id, address caller, address indexed onBehalfOf, address indexed receiver, uint256 assets, uint256 shares);

    /// @notice Emitted on repayment of assets.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param onBehalfOf The owner of the modified position.
    /// @param assets The amount of assets repaid. May be 1 over the corresponding market's `totalBorrowAssets`.
    /// @param shares The amount of shares burned.
    event DahliaRepay(IDahlia.MarketId indexed id, address indexed caller, address indexed onBehalfOf, uint256 assets, uint256 shares);

    /// @notice Emitted on liquidation of a position.
    /// @param id The market id.
    /// @param caller The caller.
    /// @param borrower The borrower of the position.
    /// @param repaidAssets The amount of assets repaid. May be 1 over the corresponding market's `totalBorrowAssets`.
    /// @param repaidShares The amount of shares burned.
    /// @param seizedCollateral The amount of collateral seized.
    /// @param badDebtAssets The amount of bad debt assets realized, includes rescued.
    /// @param badDebtShares The amount of bad debt shares realized, includes rescued.
    /// @param rescuedAssets The amount of repaid bad assets from reserve wallet.
    /// @param rescuedShares The amount of repaid bad shares from reserve wallet.
    event DahliaLiquidate(
        IDahlia.MarketId indexed id,
        address indexed caller,
        address indexed borrower,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedCollateral,
        uint256 bonusCollateral,
        uint256 badDebtAssets,
        uint256 badDebtShares,
        uint256 rescuedAssets,
        uint256 rescuedShares
    );

    /// @notice Emitted on reallocate of a position.
    /// @param fromMarketId The market fromMarketId.
    /// @param toMarketId The market toMarketId.
    /// @param caller The caller.
    /// @param borrower The borrower of the position.
    /// @param relocatedAssets The amount of assets repaid
    /// @param collateralBefore The amount of collateral seized.
    /// @param collateralAfter The amount of collateral seized.
    /// @param collateralBonus The amount of collateral seized.
    event DahliaReallocate(
        IDahlia.MarketId indexed fromMarketId,
        IDahlia.MarketId indexed toMarketId,
        address caller,
        address indexed borrower,
        uint256 relocatedAssets,
        uint256 relocatedShares,
        uint256 collateralBefore,
        uint256 collateralAfter,
        uint256 collateralBonus
    );

    /// @notice Emitted when accruing interest.
    /// @param id The market id.
    /// @param prevBorrowRate The previous borrow rate.
    /// @param interest The amount of interest accrued.
    /// @param protocolFeeShares The amount of shares minted as protocol fee shares.
    /// @param reserveFeeShares The amount of shares minted as reserve fee shares.
    event DahliaAccrueInterest(IDahlia.MarketId indexed id, uint256 prevBorrowRate, uint256 interest, uint256 protocolFeeShares, uint256 reserveFeeShares);

    /// @notice Emitted on flash loan.
    /// @param caller The caller.
    /// @param token The token that was flash loaned.
    /// @param assets The amount that was flash loaned.
    /// @param fee The amount of fee.
    event DahliaFlashLoan(address indexed caller, address indexed token, uint256 assets, uint256 fee);
}
