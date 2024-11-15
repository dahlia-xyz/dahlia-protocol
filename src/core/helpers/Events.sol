// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/**
 * @title Events library
 * @dev Contains all the protocol events.
 */
library Events {
    /// @dev Emitted when the protocol fee rate is updated.
    /// @param id Market id.
    /// @param newFee The updated fee rate.
    event SetProtocolFeeRate(IDahlia.MarketId indexed id, uint256 newFee);

    /// @dev Emitted when the reserve fee rate is updated.
    /// @param id Market id.
    /// @param newFee The updated fee rate.
    event SetReserveFeeRate(IDahlia.MarketId indexed id, uint256 newFee);

    /// @dev Emitted when the protocol fee recipient is changed.
    /// @param newProtocolFeeRecipient Address of the new fee recipient.
    event SetProtocolFeeRecipient(address indexed newProtocolFeeRecipient);

    /// @dev Emitted when the reserve fee recipient is changed.
    /// @param newReserveFeeRecipient Address of the new reserve fee recipient.
    event SetReserveFeeRecipient(address indexed newReserveFeeRecipient);

    /// @dev Emitted when the flash loan fee rate is updated.
    /// @param newFee The updated flash loan fee rate.
    event SetFlashLoanFeeRate(uint256 newFee);

    /// @dev Emitted when a new LLTV range is set.
    /// @param minLltv Minimum LLTV value.
    /// @param maxLltv Maximum LLTV value.
    event SetLLTVRange(uint256 minLltv, uint256 maxLltv);

    /// @dev Emitted when a new liquidation bonus rate range is set.
    /// @param minLltv Minimum liquidation bonus rate.
    /// @param maxLltv Maximum liquidation bonus rate.
    event SetLiquidationBonusRateRange(uint256 minLltv, uint256 maxLltv);

    /// @dev Emitted when the market status changes.
    /// @param from Previous market status.
    /// @param to New market status.
    event MarketStatusChanged(IDahlia.MarketStatus from, IDahlia.MarketStatus to);

    /// @dev Emitted when the liquidation bonus rate changes.
    /// @param liquidationBonusRate The updated liquidation bonus rate.
    event LiquidationBonusRateChanged(uint256 liquidationBonusRate);

    /// @dev Emitted when a new market is deployed.
    /// @param id Market id.
    /// @param vault Address of the Royco WrappedVault associated with the market.
    /// @param marketConfig Configuration parameters for the market.
    event DeployMarket(IDahlia.MarketId indexed id, IWrappedVault indexed vault, IDahlia.MarketConfig marketConfig);

    /// @dev Emitted when permissions are updated.
    /// @param sender Address of the sender.
    /// @param owner Address of the owner.
    /// @param permitted Address that is permitted.
    /// @param newIsPermitted New permission status.
    event updatePermission(address indexed sender, address indexed owner, address indexed permitted, bool newIsPermitted);

    /// @dev Emitted when collateral is supplied.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param assets Amount of assets supplied as collateral.
    event SupplyCollateral(IDahlia.MarketId indexed id, address indexed caller, address indexed owner, uint256 assets);

    /// @dev Emitted when collateral is withdrawn.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param receiver Address receiving the withdrawn assets.
    /// @param assets Amount of assets withdrawn.
    event WithdrawCollateral(IDahlia.MarketId indexed id, address caller, address indexed owner, address indexed receiver, uint256 assets);

    /// @dev Emitted when assets are supplied.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param assets Amount of assets supplied.
    /// @param shares Amount of shares minted.
    event Lend(IDahlia.MarketId indexed id, address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /// @dev Emitted when assets are withdrawn.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param receiver Address receiving the withdrawn assets.
    /// @param assets Amount of assets withdrawn.
    /// @param shares Amount of shares burned.
    event Withdraw(IDahlia.MarketId indexed id, address caller, address indexed owner, address indexed receiver, uint256 assets, uint256 shares);

    /// @dev Emitted when assets are borrowed.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param receiver Address receiving the borrowed assets.
    /// @param assets Amount of assets borrowed.
    /// @param shares Amount of shares minted.
    event DahliaBorrow(IDahlia.MarketId indexed id, address caller, address indexed owner, address indexed receiver, uint256 assets, uint256 shares);

    /// @dev Emitted when assets are repaid.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param owner Address of the position owner.
    /// @param assets Amount of assets repaid.
    /// @param shares Amount of shares burned.
    event DahliaRepay(IDahlia.MarketId indexed id, address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /// @dev Emitted when a position is liquidated.
    /// @param id Market id.
    /// @param caller Address of the caller.
    /// @param borrower Address of the borrower.
    /// @param repaidAssets Amount of assets repaid.
    /// @param repaidShares Amount of shares burned.
    /// @param seizedCollateral Amount of collateral seized.
    /// @param bonusCollateral Amount of bonus collateral.
    /// @param badDebtAssets Amount of bad debt assets realized.
    /// @param badDebtShares Amount of bad debt shares realized.
    /// @param rescuedAssets Amount of assets rescued from reserve.
    /// @param rescuedShares Amount of shares rescued from reserve.
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

    /// @dev Emitted when interest is accrued.
    /// @param id Market id.
    /// @param prevBorrowRate Previous borrow rate.
    /// @param interest Amount of interest accrued.
    /// @param protocolFeeShares Shares minted as protocol fee.
    /// @param reserveFeeShares Shares minted as reserve fee.
    event DahliaAccrueInterest(IDahlia.MarketId indexed id, uint256 prevBorrowRate, uint256 interest, uint256 protocolFeeShares, uint256 reserveFeeShares);

    /// @dev Emitted when a flash loan is executed.
    /// @param caller Address of the caller.
    /// @param token Address of the token flash loaned.
    /// @param assets Amount of assets flash loaned.
    /// @param fee Fee amount for the flash loan.
    event DahliaFlashLoan(address indexed caller, address indexed token, uint256 assets, uint256 fee);
}
