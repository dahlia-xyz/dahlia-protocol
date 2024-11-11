// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/**
 * @title BorrowImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library LiquidationImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;

    function internalLiquidate(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage borrowerPosition,
        IDahlia.MarketUserPosition storage reservePosition,
        address borrower
    ) internal returns (uint256, uint256, uint256) {
        uint256 rescueAssets;
        uint256 rescueShares;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalBorrowShares = market.totalBorrowShares;

        // get collateral price from oracle
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        // calc current loan-to-value of borrower position
        uint256 positionLTV = MarketMath.getLTV(totalBorrowAssets, totalBorrowShares, borrowerPosition, collateralPrice);
        // check is borrower not healthy
        if (positionLTV < market.lltv) {
            revert Errors.HealthyPositionLiquidation(positionLTV, market.lltv);
        }
        uint256 borrowShares = borrowerPosition.borrowShares;
        uint256 collateral = borrowerPosition.collateral;
        uint256 liquidationBonusRate = market.liquidationBonusRate;

        // calculate collateral to seize and bad data
        (uint256 borrowAssets, uint256 seizedCollateral, uint256 bonusCollateral, uint256 badDebtAssets, uint256 badDebtShares) =
            MarketMath.calcLiquidation(totalBorrowAssets, totalBorrowShares, collateral, collateralPrice, borrowShares, liquidationBonusRate);

        // remove all shares from position
        borrowerPosition.borrowShares = 0;
        // remove all seizedCollateral from position, always seizedCollateral <= collateral
        borrowerPosition.collateral -= seizedCollateral;
        // remove all position assets from market
        market.totalBorrowAssets -= borrowAssets;
        // remove all position shares from market
        market.totalBorrowShares -= borrowShares;

        if (badDebtAssets > 0) {
            // calc available rescue shares from reserved position
            uint256 reserveShares = reservePosition.lendShares;
            // if we have reserves for bad debt lend shares we need to calculate them with borrow shares
            if (reserveShares > 0) {
                // calc rescue assets and  shares by total lends
                (rescueAssets, rescueShares) = MarketMath.calcRescueAssets(market.totalLendAssets, market.totalLendShares, badDebtAssets, reserveShares);
                // decrease reserve lend shares
                reservePosition.lendShares -= rescueShares;
                // decrease total lend shares
                market.totalLendShares -= rescueShares;
            }
            // decrease total lend assets without rescueAssets
            market.totalLendAssets -= (badDebtAssets - rescueAssets);
        }

        // calc repaid assets and shares
        uint256 repaidAssets = borrowAssets - badDebtAssets;
        uint256 repaidShares = borrowShares - badDebtShares;

        emit Events.DahliaLiquidate(
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
