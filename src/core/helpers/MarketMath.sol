// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title MarketMath
/// @dev : The implication math for Dahlia

library MarketMath {
    using FixedPointMathLib for uint256;
    using SharesMathLib for *;
    using LibString for uint256;

    function collateralToLendUp(uint256 collateral, uint256 collateralPrice) internal pure returns (uint256) {
        return collateral.mulDivUp(collateralPrice, Constants.ORACLE_PRICE_SCALE);
    }

    function collateralToLendDown(uint256 collateral, uint256 collateralPrice) internal pure returns (uint256) {
        return collateral.mulDiv(collateralPrice, Constants.ORACLE_PRICE_SCALE);
    }

    function lendToCollateralDown(uint256 assets, uint256 collateralPrice) internal pure returns (uint256) {
        return assets.mulDiv(Constants.ORACLE_PRICE_SCALE, collateralPrice);
    }

    function lendToCollateralUp(uint256 assets, uint256 collateralPrice) internal pure returns (uint256) {
        return assets.mulDiv(Constants.ORACLE_PRICE_SCALE, collateralPrice);
    }

    /// @notice get percentage down (x * %) / 100
    function mulPercentDown(uint256 value, uint256 percent) internal pure returns (uint256) {
        return value.mulDiv(percent, Constants.LLTV_100_PERCENT);
    }

    /// @notice get percentage up (x * %) / 100
    function mulPercentUp(uint256 value, uint256 percent) internal pure returns (uint256) {
        return value.mulDivUp(percent, Constants.LLTV_100_PERCENT);
    }

    /// @notice get percentage down (x * 100) / %
    function divPercentDown(uint256 value, uint256 percent) internal pure returns (uint256) {
        return value.mulDiv(Constants.LLTV_100_PERCENT, percent);
    }

    /// @notice get percentage down (x * 100) / %
    function divPercentUp(uint256 value, uint256 percent) internal pure returns (uint256) {
        return value.mulDivUp(Constants.LLTV_100_PERCENT, percent);
    }

    /// @notice Converts a uint256 value to a string representation of percent with 1 decimal.
    /// @param value The uint256 value to convert.
    /// @return The string representation of the value in ether with two decimal places.
    function toPercentString(uint256 value) public pure returns (string memory) {
        uint256 integerPart = value * 100 / Constants.LLTV_100_PERCENT; // Get the whole number part
        uint256 fractionalValue = value * 100 % Constants.LLTV_100_PERCENT;
        uint256 divider = Constants.LLTV_100_PERCENT / 10;
        uint256 fractionalPart = fractionalValue / divider; // Get the fractional part (1 decimal places)
        require(fractionalValue % divider == 0, Errors.LltvInvalidPrecision());
        string memory integerString = integerPart.toString();
        return fractionalPart == 0 ? integerString : string(abi.encodePacked(integerString, ".", fractionalPart.toString()));
    }

    function calcLiquidation(
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 collateral,
        uint256 collateralPrice,
        uint256 borrowShares,
        uint256 liquidationBonusRate
    ) internal pure returns (uint256 borrowedAssets, uint256 seizedCollateral, uint256 bonusCollateral, uint256 badDebtInAssets, uint256 badDebtInShares) {
        // convert borrow shares to assets
        borrowedAssets = borrowShares.toAssetsDown(totalBorrowAssets, totalBorrowShares);
        // convert borrowed assets to collateral assets by oracle price
        uint256 borrowedInCollateral = lendToCollateralUp(borrowedAssets, collateralPrice);
        // we need to limit collateral by 100% LTV for bonus calculation (for bad debts protection)
        uint256 limitedCollateralForCalcBonus = FixedPointMathLib.min(borrowedInCollateral, collateral);
        // calculate liquidator bonus
        bonusCollateral = mulPercentUp(limitedCollateralForCalcBonus, liquidationBonusRate);
        // get amount of collateral assets what we need to seize from borrower
        seizedCollateral = borrowedInCollateral + bonusCollateral;

        // check if its bad debt
        if (seizedCollateral > collateral) {
            // get amount of bad dept in collateral assets
            uint256 badDebtInCollateral = seizedCollateral - collateral;
            // convert it to loan assets
            badDebtInAssets = collateralToLendUp(badDebtInCollateral, collateralPrice);
            // and to shares
            badDebtInShares = badDebtInAssets.toSharesUp(totalBorrowAssets, totalBorrowShares);
            // decrease seized collateral
            seizedCollateral = collateral;
        }
    }

    function calcRescueAssets(uint256 totalLendAssets, uint256 totalLendShares, uint256 badDebtAssets, uint256 reserveShares)
        internal
        pure
        returns (uint256 rescueAssets, uint256 rescueShares)
    {
        // convert reserve shares to  assets
        uint256 reserveAssets = reserveShares.toAssetsUp(totalLendAssets, totalLendShares);
        // calc amount assets of reserve shares and get min with badDebtAssets
        rescueAssets = FixedPointMathLib.min(badDebtAssets, reserveAssets);
        // calc shares from assets
        rescueShares = rescueAssets.toSharesDown(totalLendAssets, totalLendShares);
    }

    /// @notice Get max liquidation bonus rate
    /// @dev This should protect from case lltv + bonus > 100%
    //  @dev example: if lltv 90%, max liquidation rate wiil be (100 - 90) * 3 / 4 = 7.5
    function getMaxLiquidationBonusRate(uint256 lltv) public pure returns (uint256) {
        return FixedPointMathLib.min(Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE, (Constants.LLTV_100_PERCENT - lltv) * 3 / 4);
    }

    /// @dev Returns true if there is exactly one zero among `x` and `y`.
    function validateExactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z) {
        assembly {
            z := xor(iszero(x), iszero(y))
        }
        require(z, Errors.InconsistentAssetsOrSharesInput());
    }

    /// @notice Returns current and maximum assets for borrow (by market LLTV)
    function calcMaxBorrowAssets(IDahlia.Market memory market, IDahlia.MarketUserPosition memory position, uint256 collateralPrice)
        internal
        view
        returns (uint256 borrowedAssets, uint256 maxBorrowAssets)
    {
        // if sent 0 price, get it from oracle (for gas saving purposes)
        if (collateralPrice == 0) {
            collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        }
        // calculate actual borrow assets by shares
        borrowedAssets = position.borrowShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        // convert borrow assets to collateral amount
        uint256 totalCollateralCapacity = collateralToLendUp(position.collateral, collateralPrice);
        // decrease collateral value by market LLTV for getting max borrow amount
        maxBorrowAssets = mulPercentUp(totalCollateralCapacity, market.lltv);
    }

    /// @notice Get current borrow position LTV in Market
    function getLTV(uint256 totalBorrowAssets, uint256 totalBorrowShares, IDahlia.MarketUserPosition memory position, uint256 collateralPrice)
        internal
        pure
        returns (uint256)
    {
        // decrease collateral value by market LLTV for getting max borrow amount
        uint256 borrowedAssets = position.borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
        // get position LTV
        return getLTV(borrowedAssets, position.collateral, collateralPrice);
    }

    /// @notice Get current borrow position LTV in Market
    function getLTV(uint256 borrowedAssets, uint256 collateral, uint256 collateralPrice) internal pure returns (uint256) {
        uint256 totalCollateralCapacity = collateralToLendUp(collateral, collateralPrice);
        return borrowedAssets.mulDivUp(Constants.LLTV_100_PERCENT, totalCollateralCapacity);
    }

    /// @notice Get current collateral price
    /// @dev Precision is 1e36
    function getCollateralPrice(IDahliaOracle oracle) internal view returns (uint256 collateralPrice) {
        bool isBadData;
        (collateralPrice, isBadData) = oracle.getPrice();
        require(!isBadData && collateralPrice > 0, Errors.OraclePriceBadData());
    }
}
