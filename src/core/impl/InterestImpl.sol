// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Events } from "src/core/helpers/Events.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

/**
 * @title InterestImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library InterestImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;

    /// @dev Accrues interest for the given market `marketConfig`.
    /// @dev Assumes that the inputs `marketConfig` and `id` match.
    function executeMarketAccrueInterest(
        IDahlia.Market storage market,
        IDahlia.MarketUserPosition storage protocolFeeRecipientPosition,
        IDahlia.MarketUserPosition storage reserveFeeRecipientPosition
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
        (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
            IIrm(market.irm).calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, market.fullUtilizationRate);

        if (interestEarnedAssets > 0) {
            market.fullUtilizationRate = uint64(newFullUtilizationRate);
            market.ratePerSec = uint64(newRatePerSec);
            market.totalBorrowAssets += interestEarnedAssets;
            market.totalLendAssets += interestEarnedAssets;

            // calculate protocol fee
            uint256 totalLendShares = market.totalLendShares;
            uint256 protocolFeeShares = 0;
            uint256 protocolFeeRate = market.protocolFeeRate;
            if (protocolFeeRate > 0) {
                protocolFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, protocolFeeRate);
                protocolFeeRecipientPosition.lendShares += protocolFeeShares.toUint128();
                market.totalLendShares += protocolFeeShares;
            }

            // calculate reserve fee
            uint256 reserveFeeShares = 0;
            uint256 reserveFeeRate = market.reserveFeeRate;
            if (reserveFeeRate > 0) {
                reserveFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, reserveFeeRate);
                reserveFeeRecipientPosition.lendShares += reserveFeeShares.toUint128();
                market.totalLendShares += reserveFeeShares;
            }

            emit Events.DahliaAccrueInterest(market.id, newRatePerSec, interestEarnedAssets, protocolFeeShares, reserveFeeShares);
            market.updatedAt = uint48(block.timestamp);
        }
    }

    function calcFeeSharesFromInterest(uint256 totalLendAssets, uint256 totalLendShares, uint256 interestEarnedAssets, uint256 feeRate)
        internal
        pure
        returns (uint256 feeShares)
    {
        feeShares = (interestEarnedAssets * feeRate * totalLendShares) / (Constants.FEE_PRECISION * (totalLendAssets + interestEarnedAssets));
    }

    /// @notice Returns the expected market balances of a market after having accrued interest.
    /// @return market balances with update of interest
    function getLastMarketState(IDahlia.Market memory market, uint256 assets) internal view returns (IDahlia.Market memory) {
        uint256 totalBorrowAssets = market.totalBorrowAssets;

        // Skipped if elapsed == 0 or totalBorrowAssets == 0 because interest would be null, or if irm == address(0).
        if (totalBorrowAssets != 0 && address(market.irm) != address(0)) {
            uint256 totalLendAssets = market.totalLendAssets + assets;
            uint256 totalLendShares = market.totalLendShares;
            uint256 fullUtilizationRate = market.fullUtilizationRate;
            uint256 reserveFeeRate = market.reserveFeeRate;
            uint256 protocolFeeRate = market.protocolFeeRate;
            uint256 deltaTime = block.timestamp - market.updatedAt;
            (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
                IIrm(market.irm).calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, fullUtilizationRate);

            uint256 protocolFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, protocolFeeRate);
            uint256 reserveFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, reserveFeeRate);

            market.totalLendShares = totalLendShares + protocolFeeShares + reserveFeeShares;
            market.fullUtilizationRate = uint64(newFullUtilizationRate);
            market.ratePerSec = uint64(newRatePerSec);
            market.totalBorrowAssets += interestEarnedAssets;
            market.totalLendAssets += interestEarnedAssets;
        }
        return market;
    }
}
