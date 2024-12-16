// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/// @title LendImpl library
/// @notice Implements protocol lending functions
library LendImpl {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;

    function internalLend(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 assets, address owner)
        internal
        returns (uint256 shares)
    {
        require(market.status != IDahlia.MarketStatus.Stale, Errors.MarketStalled());

        shares = assets.toSharesDown(market.totalLendAssets, market.totalLendShares);

        ownerPosition.lendShares += shares.toUint128();
        ownerPosition.lendPrincipalAssets += assets.toUint128();
        market.totalLendPrincipalAssets += assets;
        market.totalLendShares += shares;
        market.totalLendAssets += assets;

        emit IDahlia.Lend(market.id, msg.sender, owner, assets, shares);
    }

    function internalWithdraw(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 shares, address owner, address receiver)
        internal
        returns (uint256 assets, uint256 ownerLendShares)
    {
        require(market.status != IDahlia.MarketStatus.Stale, Errors.MarketStalled());

        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;
        assets = shares.toAssetsDown(totalLendAssets, totalLendShares);
        totalLendAssets -= assets;
        if (market.totalBorrowAssets > totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, totalLendAssets);
        }
        ownerLendShares = ownerPosition.lendShares - shares;
        ownerPosition.lendShares = ownerLendShares.toUint128();
        market.totalLendShares = totalLendShares - shares;
        market.totalLendAssets = totalLendAssets;

        emit IDahlia.Withdraw(market.id, msg.sender, receiver, owner, assets, shares);
    }

    function internalWithdrawDepositAndClaimCollateral(
        IDahlia.Market storage market,
        IDahlia.UserPosition storage ownerPosition,
        address owner,
        address receiver
    ) internal returns (uint256 lendAssets, uint256 collateralAssets) {
        uint256 totalCollateralAssets = market.totalCollateralAssets;
        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalLendShares = market.totalLendShares;
        uint256 shares = uint256(ownerPosition.lendShares);
        require(shares > 0, Errors.ZeroAssets());

        // calculate owner assets based on liquidity in the market
        lendAssets = shares.toAssetsDown(totalLendAssets - totalBorrowAssets, totalLendShares);
        totalLendAssets -= lendAssets;
        // calculate owed collateral based on lend shares
        collateralAssets = shares.toAssetsDown(totalCollateralAssets, totalLendShares);
        totalCollateralAssets -= collateralAssets;

        market.vault.burnShares(owner, shares);
        ownerPosition.lendShares = 0;
        market.totalLendShares = totalLendShares - shares;
        market.totalLendAssets = totalLendAssets;
        market.totalCollateralAssets = totalCollateralAssets;

        emit IDahlia.WithdrawDepositAndClaimCollateral(market.id, msg.sender, receiver, owner, lendAssets, collateralAssets, shares);
    }
}
