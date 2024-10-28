// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {BorrowImpl} from "src/core/impl/BorrowImpl.sol";
import {IDahliaLiquidateCallback} from "src/core/interfaces/IDahliaCallbacks.sol";
import {Types} from "src/core/types/Types.sol";

/**
 * @title BorrowImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library LiquidationImpl {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;

    function internalLiquidate(
        Types.Market storage market,
        Types.MarketUserPosition storage borrowerPosition,
        Types.MarketUserPosition storage reservePosition,
        address borrower,
        bytes calldata callbackData
    ) internal returns (uint256, uint256, uint256) {
        uint256 rescueAssets;
        uint256 rescueShares;
        // get collateral price from oracle
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        // calc current loan-to-value of borrower position
        uint256 positionLTV = MarketMath.getLTV(market, borrowerPosition, collateralPrice);
        // check is borrower not healthy
        if (positionLTV < market.lltv) {
            revert Errors.HealthyPositionLiquidation(positionLTV, market.lltv);
        }
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalBorrowShares = market.totalBorrowShares;
        uint256 borrowShares = borrowerPosition.borrowShares;
        uint256 collateral = borrowerPosition.collateral;
        uint256 liquidationBonusRate = market.liquidationBonusRate;

        // calculate collateral to seize and bad data
        (
            uint256 borrowAssets,
            uint256 seizedCollateral,
            uint256 bonusCollateral,
            uint256 badDebtAssets,
            uint256 badDebtShares
        ) = MarketMath.calcLiquidation(
            totalBorrowAssets, totalBorrowShares, collateral, collateralPrice, borrowShares, liquidationBonusRate
        );

        // remove all shares from position
        borrowerPosition.borrowShares -= borrowShares;
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
                (rescueAssets, rescueShares) = MarketMath.calcRescueAssets(
                    market.totalLendAssets, market.totalLendShares, badDebtAssets, reserveShares
                );
                // decrease reserve lend shares
                reservePosition.lendShares -= rescueShares;
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

        // transfer  collateral (seized) to liquidator wallet from Dahlia wallet
        IERC20(market.collateralToken).safeTransfer(msg.sender, seizedCollateral);

        // this callback is for smart contract to receive repaid amount before they approve in collateral token
        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaLiquidateCallback(msg.sender).onDahliaLiquidate(repaidAssets, callbackData);
        }

        // transfer (repaid) assets from liquidator wallet to Dahlia wallet
        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        return (repaidAssets, repaidShares, seizedCollateral);
    }

    function internalReallocate(
        Types.Market storage market,
        Types.Market storage marketTo,
        Types.MarketUserPosition storage borrowerPosition,
        Types.MarketUserPosition storage borrowerPositionTo,
        address borrower
    ) internal returns (uint256, uint256, uint256, uint256) {
        // get collateral price from oracle
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        uint256 borrowShares = borrowerPosition.borrowShares;
        uint256 collateral = borrowerPosition.collateral;
        // get borrow assets from borrow shares
        uint256 borrowAssets = borrowShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        // calc current loan-to-value of borrower position
        uint256 positionLTV = borrowAssets.getLTV(collateral, collateralPrice);

        // we allow relocate only when rltv < ltv
        require(positionLTV >= market.rltv, Errors.HealthyPositionReallocation(positionLTV, market.rltv));
        require(positionLTV < market.lltv, "ERROR_LIQUIDITY"); // TODO: do we nett this check

        // execute repayment in Market A
        (uint256 repaidAssets,) = BorrowImpl.internalRepay(market, borrowerPosition, 0, borrowShares, borrower);
        // execute withdraw collateral in Market A
        BorrowImpl.internalWithdrawCollateral(market, borrowerPosition, collateral, borrower, borrower);

        // calculate bonus for relocator with borrowAssets by reallocationBonusRate
        uint256 bonusByBorrowAssets = borrowAssets.mulPercentDown(market.reallocationBonusRate);
        // convert bonus from loan to collateral
        uint256 bonusCollateral = bonusByBorrowAssets.lendToCollateralUp(collateralPrice);

        // decrease borrower collateral by this bonus
        uint256 newCollateral = collateral - bonusCollateral;

        // execute supply collateral in Market B
        BorrowImpl.internalSupplyCollateral(market, borrowerPositionTo, newCollateral, borrower);

        // execute borrow in Market B
        (uint256 newAssets, uint256 newShares) = BorrowImpl.internalBorrow(
            marketTo, borrowerPositionTo, borrowAssets, 0, borrower, borrower, collateralPrice
        );
        // repaidAssets and newAssets must be the same
        require(repaidAssets == newAssets, "repaidAssets != newAssets"); // TODO: temporary check

        emit Events.DahliaReallocate(
            market.id,
            marketTo.id,
            msg.sender,
            borrower,
            newAssets,
            newShares,
            collateral,
            newCollateral,
            bonusCollateral
        );

        // transfer bonus collateral assets to reallocator wallet
        if (bonusCollateral > 0) {
            IERC20(market.collateralToken).safeTransfer(msg.sender, bonusCollateral);
        }
        return (newAssets, newShares, newCollateral, bonusCollateral);
    }
}
