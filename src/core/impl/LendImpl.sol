// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";

/**
 * @title LendImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library LendImpl {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;

    function internalLend(
        Types.Market storage market,
        Types.MarketUserPosition storage marketOnBehalfOfPosition,
        uint256 assets,
        address onBehalfOf
    ) internal returns (uint256 shares) {
        shares = assets.toSharesDown(market.totalLendAssets, market.totalLendShares);

        marketOnBehalfOfPosition.lendShares += shares;
        market.totalLendShares += shares;
        market.totalLendAssets += assets;

        emit Events.Lend(market.id, msg.sender, onBehalfOf, assets, shares);
    }

    function internalWithdraw(
        Types.Market storage market,
        Types.MarketUserPosition storage marketOnBehalfOfPosition,
        uint256 shares,
        address onBehalfOf,
        address receiver
    ) internal returns (uint256) {
        uint256 assets = shares.toAssetsDown(market.totalLendAssets, market.totalLendShares);

        uint256 userInterest = marketOnBehalfOfPosition.interestAccumulated;
        uint256 maxInterest = FixedPointMathLib.min(userInterest, assets);
        marketOnBehalfOfPosition.interestAccumulated -= maxInterest;
        marketOnBehalfOfPosition.lendShares -= shares;
        market.totalLendShares -= shares;
        market.totalLendAssets -= assets;

        if (market.totalBorrowAssets > market.totalLendAssets) {
            revert Errors.InsufficientLiquidity(market.totalBorrowAssets, market.totalLendAssets);
        }
        emit Events.Withdraw(market.id, msg.sender, onBehalfOf, receiver, assets, shares);

        return (assets);
    }
}
