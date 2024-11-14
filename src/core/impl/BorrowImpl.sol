// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/**
 * @title BorrowImpl library
 * @notice Implements borrowing protocol functions
 */
library BorrowImpl {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;
    using MarketMath for uint256;

    // Add collateral to a borrower's position
    function internalSupplyCollateral(IDahlia.Market storage market, IDahlia.MarketUserPosition storage onBehalfOfPosition, uint256 assets, address onBehalfOf)
        internal
    {
        onBehalfOfPosition.collateral += assets.toUint128();

        emit Events.SupplyCollateral(market.id, msg.sender, onBehalfOf, assets);
    }

    // Withdraw collateral from borrower's position
    function internalWithdrawCollateral(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage position,
        uint256 assets,
        address onBehalfOf,
        address receiver
    ) internal {
        position.collateral -= assets.toUint128(); // Decrease collateral

        // Check if there's enough collateral for withdrawal
        if (position.borrowShares > 0) {
            (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, 0);
            if (borrowedAssets > maxBorrowAssets) {
                revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
            }
        }

        emit Events.WithdrawCollateral(market.id, msg.sender, onBehalfOf, receiver, assets);
    }

    // Borrow assets from the market
    function internalBorrow(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage onBehalfOfPosition,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        address receiver,
        uint256 collateralPrice // Can be 0, will be filled by function if so
    ) internal returns (uint256, uint256) {
        MarketMath.validateExactlyOneZero(assets, shares);

        // Calculate assets or shares
        if (assets > 0) {
            shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            assets = shares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares);
        }

        // Update borrow values in totals and position
        onBehalfOfPosition.borrowShares += shares.toUint128();
        market.totalBorrowAssets += assets;
        market.totalBorrowShares += shares;

        // Check for sufficient liquidity
        if (market.totalBorrowAssets > market.totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, market.totalLendAssets);
        }

        // Check if user has enough collateral
        (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, onBehalfOfPosition, collateralPrice);
        if (borrowedAssets > maxBorrowAssets) {
            revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
        }

        emit Events.DahliaBorrow(market.id, msg.sender, onBehalfOf, receiver, assets, shares);
        return (assets, shares);
    }

    // Repay borrowed assets
    function internalRepay(IDahlia.Market storage market, IDahlia.MarketUserPosition storage position, uint256 assets, uint256 shares, address onBehalfOf)
        internal
        returns (uint256, uint256)
    {
        MarketMath.validateExactlyOneZero(assets, shares);
        // Calculate assets or shares
        if (assets > 0) {
            shares = assets.toSharesDown(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            assets = shares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        }
        // Update borrow values in totals and position
        position.borrowShares -= shares.toUint128();
        market.totalBorrowShares -= shares;
        market.totalBorrowAssets = market.totalBorrowAssets.zeroFloorSub(assets);

        emit Events.DahliaRepay(market.id, msg.sender, onBehalfOf, assets, shares);
        return (assets, shares);
    }
}
