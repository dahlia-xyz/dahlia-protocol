// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/// @title LiquidationImpl library
/// @notice Implements position liquidation
library LiquidationImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using SafeCastLib for uint256;

    function internalLiquidate(
        IDahlia.Market storage market,
        IDahlia.UserPosition storage borrowerPosition,
        IDahlia.UserPosition storage reservePosition,
        address borrower
    ) internal returns (uint256, uint256, uint256) {
        uint256 rescueAssets = 0;
        uint256 rescueShares = 0;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalBorrowShares = market.totalBorrowShares;

        // Retrieve collateral price from oracle
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        // Calculate the current loan-to-value (LTV) ratio of the borrower's position
        uint256 positionLTV = MarketMath.getLTV(totalBorrowAssets, totalBorrowShares, borrowerPosition, collateralPrice);
        // Verify if the borrower's position is not healthy
        if (positionLTV < market.lltv) {
            revert Errors.HealthyPositionLiquidation(positionLTV, market.lltv);
        }
        uint256 borrowShares = borrowerPosition.borrowShares;
        uint256 collateral = borrowerPosition.collateral;
        uint256 liquidationBonusRate = market.liquidationBonusRate;

        // Determine collateral to seize and any bad debt
        (uint256 borrowAssets, uint256 seizedCollateral, uint256 bonusCollateral, uint256 badDebtAssets, uint256 badDebtShares) =
            MarketMath.calcLiquidation(totalBorrowAssets, totalBorrowShares, collateral, collateralPrice, borrowShares, liquidationBonusRate);

        // Remove all shares from the borrower's position
        borrowerPosition.borrowShares = 0;
        // Deduct seized collateral from the borrower's position
        borrowerPosition.collateral -= seizedCollateral.toUint128();
        // Deduct borrower's assets from the market
        market.totalBorrowAssets -= borrowAssets;
        // Deduct borrower's shares from the market
        market.totalBorrowShares -= borrowShares;

        if (badDebtAssets > 0) {
            // Determine available shares from reserves
            uint256 reserveShares = reservePosition.lendShares;
            // Calculate rescue assets and shares if reserve funds are available to cover the bad debt
            if (reserveShares > 0) {
                (rescueAssets, rescueShares) = MarketMath.calcRescueAssets(market.totalLendAssets, market.totalLendShares, badDebtAssets, reserveShares);
                // Reduce reserve lend shares
                reservePosition.lendShares -= rescueShares.toUint128();
                // Reduce total lend shares
                market.totalLendShares -= rescueShares;
            }
            // Reduce total lend assets by the amount of bad debt minus rescue assets
            market.totalLendAssets -= (badDebtAssets - rescueAssets);
        }

        // Calculate repaid assets and shares
        uint256 repaidAssets = borrowAssets - badDebtAssets;
        uint256 repaidShares = borrowShares - badDebtShares;

        emit IDahlia.DahliaLiquidate(
            market.id,
            msg.sender,
            borrower,
            repaidAssets,
            repaidShares,
            seizedCollateral,
            bonusCollateral,
            badDebtAssets,
            badDebtShares,
            rescueAssets,
            rescueShares
        );

        return (repaidAssets, repaidShares, seizedCollateral);
    }
}
