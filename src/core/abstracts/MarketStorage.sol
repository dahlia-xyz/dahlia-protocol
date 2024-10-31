// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {InterestImpl} from "src/core/impl/InterestImpl.sol";
import {IMarketStorage} from "src/core/interfaces/IDahlia.sol";
import {Types} from "src/core/types/Types.sol";

/**
 * @title MarketStorage
 * @notice Contract used as market storage for the Dahlia contract.
 * @dev It defines the storage layout of the Dahlia contract.
 */
abstract contract MarketStorage is Ownable2Step, IMarketStorage {
    mapping(Types.MarketId => Types.MarketData) internal markets;

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwnerOrAdmin(address admin) internal view {
        address sender = _msgSender();
        require(sender == owner() || sender == admin, Errors.NotPermitted(sender));
    }

    function getMarket(Types.MarketId marketId) external view returns (Types.Market memory) {
        return markets[marketId].market;
    }

    function marketUserPositions(Types.MarketId marketId, address userAddress)
        external
        view
        returns (uint256 lendShares, uint256 borrowShares, uint256 collateral)
    {
        Types.MarketUserPosition memory position = markets[marketId].userPositions[userAddress];
        lendShares = position.lendShares;
        borrowShares = position.borrowShares;
        collateral = position.collateral;
    }

    function marketUserMaxBorrows(Types.MarketId marketId, address userAddress)
        external
        view
        returns (uint256 borrowAssets, uint256 maxBorrowAssets, uint256 collateralPrice)
    {
        Types.MarketUserPosition memory position = markets[marketId].userPositions[userAddress];
        Types.Market memory market = markets[marketId].market;
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        (borrowAssets, maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, collateralPrice);
    }

    function getPositionLTV(Types.MarketId marketId, address userAddress) external view returns (uint256 ltv) {
        Types.MarketUserPosition memory position = markets[marketId].userPositions[userAddress];
        Types.Market memory market = markets[marketId].market;
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        return MarketMath.getLTV(market.totalBorrowAssets, market.totalBorrowShares, position, collateralPrice);
    }

    /// @inheritdoc IMarketStorage
    function isMarketDeployed(Types.MarketId marketId) external view virtual returns (bool) {
        return markets[marketId].market.status != Types.MarketStatus.None;
    }

    /// @inheritdoc IMarketStorage
    function pauseMarket(Types.MarketId id) external {
        Types.Market storage market = markets[id].market;
        _checkOwnerOrAdmin(market.admin);
        _validateMarket(market.status, false);
        require(market.status == Types.MarketStatus.Active, Errors.CannotChangeMarketStatus());
        emit Events.MarketStatusChanged(market.status, Types.MarketStatus.Paused);
        market.status = Types.MarketStatus.Paused;
    }

    /// @inheritdoc IMarketStorage
    function unpauseMarket(Types.MarketId id) external {
        Types.Market storage market = markets[id].market;
        _checkOwnerOrAdmin(market.admin);
        _validateMarket(market.status, false);
        require(market.status == Types.MarketStatus.Paused, Errors.CannotChangeMarketStatus());
        emit Events.MarketStatusChanged(market.status, Types.MarketStatus.Active);
        market.status = Types.MarketStatus.Active;
    }

    /// @inheritdoc IMarketStorage
    function deprecateMarket(Types.MarketId id) external onlyOwner {
        Types.Market storage market = markets[id].market;
        _validateMarket(market.status, false);
        emit Events.MarketStatusChanged(market.status, Types.MarketStatus.Deprecated);
        market.status = Types.MarketStatus.Deprecated;
    }

    /// @inheritdoc IMarketStorage
    function updateMarketBonusRates(Types.MarketId id, uint256 liquidationBonusRate, uint256 reallocationBonusRate)
        external
    {
        require(reallocationBonusRate < liquidationBonusRate, Errors.MarketReallocationLtvInsufficient());
        Types.Market storage market = markets[id].market;
        _checkOwnerOrAdmin(market.admin);
        _validateLiquidationBonusRate(liquidationBonusRate, market.lltv);
        _validateReallocationBonusRate(reallocationBonusRate, market.rltv);
        emit Events.MarketBonusRatesChanged(liquidationBonusRate, reallocationBonusRate);
        market.liquidationBonusRate = uint24(liquidationBonusRate);
        market.reallocationBonusRate = uint24(reallocationBonusRate);
    }

    function updateMarketAdmin(Types.MarketId id, address newAdmin) external {
        Types.Market storage market = markets[id].market;
        address oldAdmin = market.admin;
        _checkOwnerOrAdmin(oldAdmin);
        emit Events.MarketAdminChanged(oldAdmin, newAdmin);
        market.admin = newAdmin;
    }

    /// @inheritdoc IMarketStorage
    function getLastMarketState(Types.MarketId id)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        Types.Market storage market = markets[id].market;
        _validateMarket(market.status, false);
        return InterestImpl.getLastMarketState(market);
    }

    function _validateMarket(Types.MarketStatus status, bool checkIsSupplyAndBorrowForbidden) internal pure {
        require(status != Types.MarketStatus.None, Errors.MarketNotDeployed());
        if (checkIsSupplyAndBorrowForbidden && status != Types.MarketStatus.Active) {
            if (status == Types.MarketStatus.Deprecated) {
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
