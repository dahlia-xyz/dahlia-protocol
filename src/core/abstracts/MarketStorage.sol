// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { IMarketStorage } from "src/core/interfaces/IDahlia.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/**
 * @title MarketStorage
 * @notice Contract used as market storage for the Dahlia contract.
 * @dev It defines the storage layout of the Dahlia contract.
 */
abstract contract MarketStorage is Ownable2Step, IMarketStorage {
    mapping(MarketId => MarketData) internal markets;

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkDahliaOwnerOrVaultOwner(IWrappedVault vault) internal view {
        address sender = _msgSender();
        require(sender == owner() || sender == vault.vaultOwner(), Errors.NotPermitted(sender));
    }

    function getMarket(MarketId id) external view returns (Market memory) {
        return InterestImpl.getLastMarketState(markets[id].market, 0);
    }

    function getMarketUserPosition(MarketId marketId, address userAddress) external view returns (MarketUserPosition memory) {
        return markets[marketId].userPositions[userAddress];
    }

    function marketUserMaxBorrows(MarketId marketId, address userAddress)
        external
        view
        returns (uint256 borrowAssets, uint256 maxBorrowAssets, uint256 collateralPrice)
    {
        MarketUserPosition memory position = markets[marketId].userPositions[userAddress];
        Market memory market = markets[marketId].market;
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        (borrowAssets, maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, collateralPrice);
    }

    function getPositionLTV(MarketId marketId, address userAddress) external view returns (uint256 ltv) {
        MarketUserPosition memory position = markets[marketId].userPositions[userAddress];
        Market memory market = markets[marketId].market;
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        return MarketMath.getLTV(market.totalBorrowAssets, market.totalBorrowShares, position, collateralPrice);
    }

    /// @inheritdoc IMarketStorage
    function isMarketDeployed(MarketId marketId) external view virtual returns (bool) {
        return markets[marketId].market.status != MarketStatus.None;
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
    function updateMarketBonusRates(MarketId id, uint256 liquidationBonusRate, uint256 reallocationBonusRate) external {
        require(reallocationBonusRate < liquidationBonusRate, Errors.MarketReallocationLtvInsufficient());
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateLiquidationBonusRate(liquidationBonusRate, market.lltv);
        _validateReallocationBonusRate(reallocationBonusRate, market.rltv);
        emit Events.MarketBonusRatesChanged(liquidationBonusRate, reallocationBonusRate);
        market.liquidationBonusRate = uint24(liquidationBonusRate);
        market.reallocationBonusRate = uint24(reallocationBonusRate);
    }

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

    function _validateLiquidationBonusRate(uint256 liquidationBonusRate, uint256 lltv) internal view virtual;

    function _validateReallocationBonusRate(uint256 rate, uint256 rltv) internal pure {
        require(rate <= MarketMath.calcReallocationBonusRate(rltv), Errors.MarketReallocationLtvInsufficient());
    }
}
