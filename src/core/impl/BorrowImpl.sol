// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
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
    function internalSupplyCollateral(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 assets, address owner) internal {
        ownerPosition.collateral += assets.toUint128();

        emit IDahlia.SupplyCollateral(market.id, msg.sender, owner, assets);
    }

    // Withdraw collateral from borrower's position
    function internalWithdrawCollateral(
        IDahlia.Market storage market,
        IDahlia.UserPosition storage ownerPosition,
        uint256 assets,
        address owner,
        address receiver
    ) internal {
        ownerPosition.collateral -= assets.toUint128(); // Decrease collateral

        // Check if there's enough collateral for withdrawal
        if (ownerPosition.borrowShares > 0) {
            (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, ownerPosition, 0);
            if (borrowedAssets > maxBorrowAssets) {
                revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
            }
        }

        emit IDahlia.WithdrawCollateral(market.id, msg.sender, owner, receiver, assets);
    }

    // Borrow assets from the market
    function internalBorrow(
        IDahlia.Market storage market,
        IDahlia.UserPosition storage ownerPosition,
        uint256 assets,
        address owner,
        address receiver,
        uint256 collateralPrice // Can be 0, will be filled by function if so
    ) internal returns (uint256, uint256) {
        uint256 shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);

        // Update borrow values in totals and position
        ownerPosition.borrowShares += shares.toUint128();
        market.totalBorrowAssets += assets;
        market.totalBorrowShares += shares;

        // Check for sufficient liquidity
        if (market.totalBorrowAssets > market.totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, market.totalLendAssets);
        }

        // Check if user has enough collateral
        (uint256 borrowedAssets, uint256 maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, ownerPosition, collateralPrice);
        if (borrowedAssets > maxBorrowAssets) {
            revert Errors.InsufficientCollateral(borrowedAssets, maxBorrowAssets);
        }

        emit IDahlia.DahliaBorrow(market.id, msg.sender, owner, receiver, assets, shares);
        return (assets, shares);
    }

    // Repay borrowed assets
    function internalRepay(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 assets, uint256 shares, address owner)
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
        ownerPosition.borrowShares -= shares.toUint128();
        market.totalBorrowShares -= shares;
        market.totalBorrowAssets = market.totalBorrowAssets.zeroFloorSub(assets);

        emit IDahlia.DahliaRepay(market.id, msg.sender, owner, assets, shares);
        return (assets, shares);
    }
}
