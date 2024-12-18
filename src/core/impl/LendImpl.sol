// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/// @title LendImpl library
/// @notice Implements protocol lending functions
library LendImpl {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;

    function internalLend(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 assets, address owner)
        internal
        returns (uint256 shares)
    {
        shares = assets.toSharesDown(market.totalLendAssets, market.totalLendShares);

        ownerPosition.lendShares += uint128(shares);
        ownerPosition.lendPrincipalAssets += uint128(assets);
        market.totalLendPrincipalAssets += assets;
        market.totalLendShares += shares;
        market.totalLendAssets += assets;

        emit IDahlia.Lend(market.id, msg.sender, owner, assets, shares);
    }

    function internalWithdraw(IDahlia.Market storage market, IDahlia.UserPosition storage ownerPosition, uint256 shares, address owner, address receiver)
        internal
        returns (uint256 assets, uint256 ownerLendShares)
    {
        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;
        assets = shares.toAssetsDown(totalLendAssets, totalLendShares);
        totalLendAssets -= assets;
        if (market.totalBorrowAssets > totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, totalLendAssets);
        }
        ownerLendShares = ownerPosition.lendShares - shares;
        ownerPosition.lendShares = uint128(ownerLendShares);
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
        uint256 shares = ownerPosition.lendShares;
        require(shares > 0, Errors.ZeroAssets());
        uint256 totalCollateralAssets = market.totalCollateralAssets;
        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;

        // calculate owner assets based on liquidity in the market
        lendAssets = shares.toAssetsDown(totalLendAssets - market.totalBorrowAssets, totalLendShares);
        // Calculate owed collateral based on lendPrincipalAssets
        collateralAssets = (ownerPosition.lendPrincipalAssets * totalCollateralAssets) / market.totalLendPrincipalAssets;

        market.vault.burnShares(owner, ownerPosition.lendPrincipalAssets);
        ownerPosition.lendShares = 0;
        ownerPosition.lendPrincipalAssets = 0;
        market.totalLendShares = totalLendShares - shares;
        market.totalLendAssets = totalLendAssets - lendAssets;

        emit IDahlia.WithdrawDepositAndClaimCollateral(market.id, msg.sender, receiver, owner, lendAssets, collateralAssets, shares);
    }
}
