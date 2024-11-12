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
 * @notice Implements functions to validate the different actions of the protocol
 */
library BorrowImpl {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;
    using MarketMath for uint256;

    function internalSupplyCollateral(IDahlia.Market storage market, IDahlia.MarketUserPosition storage onBehalfOfPosition, uint256 assets, address onBehalfOf)
        internal
    {
        // increase collateral value in position
        onBehalfOfPosition.collateral += assets.toUint128();

        emit Events.SupplyCollateral(market.id, msg.sender, onBehalfOf, assets);
    }

    function internalWithdrawCollateral(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage position,
        uint256 assets,
        address onBehalfOf,
        address receiver
    ) internal {
        // decrease collateral value in position
        position.collateral -= assets.toUint128();

        // check is collateral sufficient for withdraw. If borrowShares == 0, skip for gas saving
        if (position.borrowShares > 0) {
            // get current and  max borrow assets
            (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, 0);
            // if current is more then max, then revert
            if (borrowedAssets > maxBorrowAssets) {
                revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
            }
        }

        emit Events.WithdrawCollateral(market.id, msg.sender, onBehalfOf, receiver, assets);
    }

    function internalBorrow(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage onBehalfOfPosition,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        address receiver,
        // can be zero, if 0 it will fill by function (for gas saving)
        uint256 collateralPrice
    ) internal returns (uint256, uint256) {
        MarketMath.validateExactlyOneZero(assets, shares);
        // calculate assets or shares
        if (assets > 0) {
            shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            assets = shares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares);
        }

        // in create borrow values in totals and position
        onBehalfOfPosition.borrowShares += shares.toUint128();
        market.totalBorrowAssets += assets;
        market.totalBorrowShares += shares;

        // revert if not sufficient liquidity in total lends
        if (market.totalBorrowAssets > market.totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, market.totalLendAssets);
        }

        // get current and  max borrow assets
        (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, onBehalfOfPosition, collateralPrice);
        // revert if user overflowed borrow amount, need to supply more collateral
        if (borrowedAssets > maxBorrowAssets) {
            revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
        }

        // TODO: decide if need to check by borrowedAssets or lltv bottom,
        // uint256 positionLltv = MarketMath.getLTV(market, onBehalfOfPosition, collateralPrice);
        // if (positionLltv > market.lltv) {
        //     revert Errors.InsufficientCollateral(positionLltv, market.lltv);
        // }

        emit Events.DahliaBorrow(market.id, msg.sender, onBehalfOf, receiver, assets, shares);
        return (assets, shares);
    }

    function internalRepay(IDahlia.Market storage market, IDahlia.MarketUserPosition storage position, uint256 assets, uint256 shares, address onBehalfOf)
        internal
        returns (uint256, uint256)
    {
        MarketMath.validateExactlyOneZero(assets, shares);
        // calculate assets or shares
        if (assets > 0) {
            shares = assets.toSharesDown(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            assets = shares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        }

        // decrease borrow values in totals and position
        position.borrowShares -= shares.toUint128();
        market.totalBorrowShares -= shares;
        market.totalBorrowAssets = market.totalBorrowAssets.zeroFloorSub(assets);

        emit Events.DahliaRepay(market.id, msg.sender, onBehalfOf, assets, shares);
        return (assets, shares);
    }
}
