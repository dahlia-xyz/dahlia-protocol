// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

//import { console } from "@forge-std/Test.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { IDahlia } from "src/core/contracts/Dahlia.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";

/// @title MarketMath
/// @notice Math utilities for the Dahlia protocol, handling collateral, loan calculations, and liquidation logic
/// @dev Provides safe math operations for lending and borrowing calculations
library TestMarketMath {
    using FixedPointMathLib for uint256;
    using SharesMathLib for *;
    using LibString for uint256;

    function calcMinCollateralPrice(uint256 borrowedAssets, uint256 collateral, uint256 lltv) internal pure returns (uint256) {
        // 100 USD borrowed Assets
        // 10 WBERA collateral
        // 80% lltv
        // price???
        // LTV * WBERA * P = USD
        // P = borrowedAssets / LTV / collateral
        uint256 maxBorrowable = MarketMath.divPercentUp(borrowedAssets, lltv);
        //        console.log("maxBorrowable", maxBorrowable);
        return maxBorrowable.mulDiv(Constants.ORACLE_PRICE_SCALE, collateral);
    }

    function seizedCollateral(uint256 repayShares, IDahlia.Market memory market) internal view returns (uint256 seizeCollateral) {
        (uint256 price,) = market.oracle.getPrice();
        uint256 repayAssetsForSeizedCollateral = repayShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 seizedCollateralWithoutFee = MarketMath.lendToCollateralDown(repayAssetsForSeizedCollateral, price);
        seizeCollateral = MarketMath.mulPercentDown(seizedCollateralWithoutFee, Constants.LLTV_100_PERCENT + market.liquidationBonusRate);
    }

    /**
     * @notice Calculates the number of collateral tokens to sell to lower the LTV.
     * @param borrowedAssets The loan amount (in the smallest unit, e.g. wei).
     * @param price The price per collateral token (in the smallest unit).
     * @param targetLTV The desired LTV (e.g. 75% = 0.75e3).
     * @param currentLTV The current LTV (e.g. 81% = 0.81e3).
     * @param liquidationBonusRate The liquidator fee (e.g. 5% = 0.05e3). If there is no fee, pass 0.
     * @return s The number of collateral tokens that must be sold.
     *
     * The formula implemented is:
     *   s = L * (1 - D/Z) / (P * ((1 - F) - D)).
     *
     * Note: In this implementation, 1 corresponds to 1e18.
     */
    function tokensToSell(uint256 borrowedAssets, uint256 price, uint256 targetLTV, uint256 currentLTV, uint256 liquidationBonusRate)
        public
        pure
        returns (uint256 s)
    {
        // Compute A = 1 - D/Z, but in WAD arithmetic.
        // That is, A = WAD - (D * WAD / Z).
        uint256 A = Constants.LLTV_100_PERCENT - ((targetLTV * Constants.LLTV_100_PERCENT) / currentLTV);

        // Compute B = (1 - F) - D.
        // In WAD, 1 is WAD so B = (WAD - F) - D.
        uint256 B = (Constants.LLTV_100_PERCENT - liquidationBonusRate) - targetLTV;

        // The formula is:
        //    s = (L * A) / (P * B)
        //
        // A and B are in LLTV_100_PERCENT, but since they both come from fixed-point values,
        // their ratio is dimensionless.
        s = (borrowedAssets * A * Constants.ORACLE_PRICE_SCALE) / (price * B);
    }
}
