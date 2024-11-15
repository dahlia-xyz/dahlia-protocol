// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";

/**
 * @title LendImpl library
 * @notice Implements protocol lending functions
 */
library LendImpl {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;

    function internalLend(IDahlia.Market storage market, IDahlia.MarketUserPosition storage ownerOfPosition, uint256 assets, address owner)
        internal
        returns (uint256 shares)
    {
        shares = assets.toSharesDown(market.totalLendAssets, market.totalLendShares);

        ownerOfPosition.lendShares += shares.toUint128();
        ownerOfPosition.lendAssets += assets.toUint128();
        market.totalLendShares += shares;
        market.totalLendAssets += assets;

        emit Events.Lend(market.id, msg.sender, owner, assets, shares);
    }

    function internalWithdraw(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage marketOwnerPosition,
        uint256 shares,
        address owner,
        address receiver
    ) internal returns (uint256) {
        uint256 assets = shares.toAssetsDown(market.totalLendAssets, market.totalLendShares);

        marketOwnerPosition.lendShares -= shares.toUint128();
        market.totalLendShares -= shares;
        market.totalLendAssets -= assets;

        if (market.totalBorrowAssets > market.totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, market.totalLendAssets);
        }
        emit Events.Withdraw(market.id, msg.sender, owner, receiver, assets, shares);

        return (assets);
    }
}
