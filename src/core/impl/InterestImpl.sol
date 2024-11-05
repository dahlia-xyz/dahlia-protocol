// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "src/core/helpers/Constants.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {Types} from "src/core/types/Types.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";

/**
 * @title InterestImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library InterestImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using MarketMath for uint256;
    using SafeCastLib for uint256;

    /// @notice Calculate the interest accumulated by user shares between two checkpoints.
    function _calculateUserRewards(
        uint256 interestPeriod,
        uint256 shares,
        uint256 earlierUserCheckpointRate,
        uint256 latterRewardsCheckpointRate
    ) internal pure returns (uint256) {
        return interestPeriod * shares * (latterRewardsCheckpointRate - earlierUserCheckpointRate)
            / FixedPointMathLib.WAD / 1e6; // We must scale down the rewards by the precision factor
    }

    function updateUserRewards(
        uint256 interestPeriod,
        uint256 interestRateAccumulated,
        Types.MarketUserPosition storage user
    ) internal returns (uint256 assets) {
        uint256 interestRateCheckpointed = user.interestRateCheckpointed;
        console.log("interestPeriod", interestPeriod);
        console.log("interestRateCheckpointed", interestRateCheckpointed);
        console.log("interestRateAccumulated", interestRateAccumulated);
        assets = user.interestAccumulated;
        assets +=
            _calculateUserRewards(interestPeriod, user.lendShares, interestRateCheckpointed, interestRateAccumulated);
        user.interestAccumulated = assets;
        user.interestRateCheckpointed = interestRateAccumulated;
    }

    /// @dev Accrues interest for the given market `marketConfig`.
    /// @dev Assumes that the inputs `marketConfig` and `id` match.
    function executeMarketAccrueInterest(
        Types.Market storage market,
        Types.MarketUserPosition storage protocolFeeRecipientPosition,
        Types.MarketUserPosition storage reserveFeeRecipientPosition
    ) internal {
        if (address(market.irm) == address(0)) {
            return;
        }
        uint256 deltaTime = block.timestamp - market.updatedAt;
        if (deltaTime == 0) {
            return;
        }
        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) = IIrm(market.irm)
            .calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, market.fullUtilizationRate);

        console.log("interestEarnedAssets", interestEarnedAssets);
        if (interestEarnedAssets > 0) {
            market.fullUtilizationRate = uint64(newFullUtilizationRate);
            market.ratePerSec = uint64(newRatePerSec);
            market.totalBorrowAssets += interestEarnedAssets;
            // TODO: keep to add to allow to pass tests
            market.totalLendAssets += interestEarnedAssets;

            uint256 totalLendShares = market.totalLendShares;
            // interest / totalLendShares / elapsed - rate per sec for lent shares
            uint256 lendShareInterestRate =
                (totalBorrowAssets * newRatePerSec).mulDiv(SharesMathLib.SHARES_OFFSET, totalLendShares);
            console.log("newRatePerSec", newRatePerSec);
            console.log("deltaTime", deltaTime);
            console.log("totalLendShares", totalLendShares);
            console.log("lentSharesInterestRate", lendShareInterestRate);

            //            uint256 reserveFeeTaken = interestEarnedAssets.mulPercentDown(reserveFeeRate);
            //            uint256 protocolFeeTaken = interestEarnedAssets.mulPercentDown(protocolFeeRate);
            //            uint256 interestAfterFee = interestEarnedAssets - reserveFeeTaken - protocolFeeTaken;

            market.interestRateAccumulated += lendShareInterestRate; // we accumulate rate of interest per second

            // calculate protocol fee
            uint256 protocolFeeShares = 0;
            uint256 protocolFeeRate = market.protocolFeeRate;
            if (protocolFeeRate > 0) {
                protocolFeeShares =
                    calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, protocolFeeRate);
                protocolFeeRecipientPosition.lendShares += protocolFeeShares;
                market.totalLendShares += protocolFeeShares;
            }

            // calculate reserve fee
            uint256 reserveFeeShares = 0;
            uint256 reserveFeeRate = market.reserveFeeRate;
            if (reserveFeeRate > 0) {
                reserveFeeShares =
                    calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, reserveFeeRate);
                reserveFeeRecipientPosition.lendShares += reserveFeeShares;
                market.totalLendShares += reserveFeeShares;
            }

            emit Events.DahliaAccrueInterest(
                market.id, newRatePerSec, interestEarnedAssets, protocolFeeShares, reserveFeeShares
            );
            //TODO: Safe "unchecked" cast?
            market.interestPeriod = uint48(deltaTime); // remember old updateAt to use as a start to distribute interest
            market.updatedAt = uint48(block.timestamp);
        }
    }

    function calcFeeSharesFromInterest(
        uint256 totalLendAssets,
        uint256 totalLendShares,
        uint256 interestEarnedAssets,
        uint256 feeRate
    ) internal pure returns (uint256 feeShares) {
        feeShares = (interestEarnedAssets * feeRate * totalLendShares)
            / (Constants.FEE_PRECISION * (totalLendAssets + interestEarnedAssets));
    }

    /// @notice Returns the expected market balances of a market after having accrued interest.
    /// @return totalLendAssets The expected total lend assets.
    /// @return totalLendShares The expected total lend shares.
    /// @return totalBorrowAssets The expected total borrow assets.
    /// @return totalBorrowShares The expected total borrow shares.
    function getLastMarketState(Types.Market memory market)
        internal
        view
        returns (
            uint256 totalLendAssets,
            uint256 totalLendShares,
            uint256 totalBorrowAssets,
            uint256 totalBorrowShares,
            uint256 fullUtilizationRate,
            uint256 ratePerSec
        )
    {
        totalLendAssets = market.totalLendAssets;
        totalLendShares = market.totalLendShares;
        totalBorrowAssets = market.totalBorrowAssets;
        totalBorrowShares = market.totalBorrowShares;

        uint256 deltaTime = block.timestamp - market.updatedAt;
        uint256 reserveFeeRate = market.reserveFeeRate;
        uint256 protocolFeeRate = market.protocolFeeRate;
        fullUtilizationRate = market.fullUtilizationRate;

        // Skipped if elapsed == 0 or totalBorrowAssets == 0 because interest would be null, or if irm == address(0).
        if (deltaTime > 0 && totalBorrowAssets != 0 && address(market.irm) != address(0)) {
            (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
                IIrm(market.irm).calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, fullUtilizationRate);

            uint256 protocolFeeShares =
                calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, protocolFeeRate);
            uint256 reserveFeeShares =
                calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, reserveFeeRate);
            totalLendShares += protocolFeeShares + reserveFeeShares;

            fullUtilizationRate = newFullUtilizationRate;
            ratePerSec = newRatePerSec;
            totalBorrowAssets += interestEarnedAssets;
            totalLendAssets += interestEarnedAssets;
        }
    }
}
