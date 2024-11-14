// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { IMarketStorage } from "src/core/interfaces/IDahlia.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/// @title MarketStorage
/// @notice Manages market data and storage for protocol.
abstract contract MarketStorage is Ownable2Step, IMarketStorage {
    mapping(MarketId => MarketData) internal markets;

    /// @notice Checks if the sender is the market or the wrapped vault owner.
    /// @param vault The wrapped vault associated with the market.
    function _checkDahliaOwnerOrVaultOwner(IWrappedVault vault) internal view {
        address sender = _msgSender();
        require(sender == owner() || sender == vault.vaultOwner(), Errors.NotPermitted(sender));
    }

    /// @inheritdoc IMarketStorage
    function getMarket(MarketId id) external view returns (Market memory) {
        return InterestImpl.getLastMarketState(markets[id].market, 0);
    }

    /// @inheritdoc IMarketStorage
    function getMarketUserPosition(MarketId id, address userAddress) external view returns (MarketUserPosition memory) {
        return markets[id].userPositions[userAddress];
    }

    /// @inheritdoc IMarketStorage
    function marketUserMaxBorrows(MarketId id, address userAddress)
        external
        view
        returns (uint256 borrowAssets, uint256 maxBorrowAssets, uint256 collateralPrice)
    {
        MarketUserPosition memory position = markets[id].userPositions[userAddress];
        Market memory market = markets[id].market;
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        (borrowAssets, maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, collateralPrice);
    }

    /// @inheritdoc IMarketStorage
    function getPositionLTV(MarketId id, address userAddress) external view returns (uint256 ltv) {
        MarketUserPosition memory position = markets[id].userPositions[userAddress];
        Market memory market = markets[id].market;
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        return MarketMath.getLTV(market.totalBorrowAssets, market.totalBorrowShares, position, collateralPrice);
    }

    /// @inheritdoc IMarketStorage
    function isMarketDeployed(MarketId id) external view virtual returns (bool) {
        return markets[id].market.status != MarketStatus.None;
    }

    /// @inheritdoc IMarketStorage
    function pauseMarket(MarketId id) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateMarket(market.status, false);
        require(market.status == MarketStatus.Active, Errors.CannotChangeMarketStatus());
        emit Events.MarketStatusChanged(market.status, MarketStatus.Paused);
        market.status = MarketStatus.Paused;
    }

    /// @inheritdoc IMarketStorage
    function unpauseMarket(MarketId id) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateMarket(market.status, false);
        require(market.status == MarketStatus.Paused, Errors.CannotChangeMarketStatus());
        emit Events.MarketStatusChanged(market.status, MarketStatus.Active);
        market.status = MarketStatus.Active;
    }

    /// @inheritdoc IMarketStorage
    function deprecateMarket(MarketId id) external onlyOwner {
        Market storage market = markets[id].market;
        _validateMarket(market.status, false);
        emit Events.MarketStatusChanged(market.status, MarketStatus.Deprecated);
        market.status = MarketStatus.Deprecated;
    }

    /// @inheritdoc IMarketStorage
    function updateLiquidationBonusRate(MarketId id, uint256 liquidationBonusRate) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateLiquidationBonusRate(liquidationBonusRate, market.lltv);
        emit Events.LiquidationBonusChanged(liquidationBonusRate);
        market.liquidationBonusRate = uint24(liquidationBonusRate);
    }

    /// @notice Validates the current market status and optionally checks market is paused or deprecated.
    /// @param status The current market status.
    /// @param checkIsSupplyAndBorrowForbidden If true, checks if market is paused or deprecated.
    function _validateMarket(MarketStatus status, bool checkIsSupplyAndBorrowForbidden) internal pure {
        require(status != MarketStatus.None, Errors.MarketNotDeployed());
        if (checkIsSupplyAndBorrowForbidden && status != MarketStatus.Active) {
            if (status == MarketStatus.Deprecated) {
                revert Errors.MarketDeprecated();
            } else {
                revert Errors.MarketPaused();
            }
        }
    }

    /// @notice Validates the liquidation bonus rate, ensuring it is within acceptable limits based on the market's LLTV.
    /// @param liquidationBonusRate The liquidation bonus rate to validate.
    /// @param lltv Liquidation loan-to-value for the market.
    function _validateLiquidationBonusRate(uint256 liquidationBonusRate, uint256 lltv) internal view virtual;
}
