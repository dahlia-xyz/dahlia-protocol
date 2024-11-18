// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

/**
 * @title InterestImpl library
 * @notice Implements protocol interest and fee accrual
 */
library InterestImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;

    /// @dev Accrues interest for the specified market.
    function executeMarketAccrueInterest(
        IDahlia.Market storage market,
        IDahlia.UserPosition storage protocolFeeRecipientPosition,
        IDahlia.UserPosition storage reserveFeeRecipientPosition
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

            // Calculate protocol fee
            uint256 totalLendShares = market.totalLendShares;
            uint256 protocolFeeShares = 0;
            uint256 protocolFeeRate = market.protocolFeeRate;
            if (protocolFeeRate > 0) {
                protocolFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, protocolFeeRate);
                protocolFeeRecipientPosition.lendShares += protocolFeeShares.toUint128();
                market.totalLendShares += protocolFeeShares;
            }

            // Calculate reserve fee
            uint256 reserveFeeShares = 0;
            uint256 reserveFeeRate = market.reserveFeeRate;
            if (reserveFeeRate > 0) {
                reserveFeeShares = calcFeeSharesFromInterest(totalLendAssets, totalLendShares, interestEarnedAssets, reserveFeeRate);
                reserveFeeRecipientPosition.lendShares += reserveFeeShares.toUint128();
                market.totalLendShares += reserveFeeShares;
            }

            emit IDahlia.DahliaAccrueInterest(market.id, newRatePerSec, interestEarnedAssets, protocolFeeShares, reserveFeeShares);
            market.updatedAt = uint48(block.timestamp);
        }
    }

    /// @dev Calculates fee shares from earned interest.
    function calcFeeSharesFromInterest(uint256 totalLendAssets, uint256 totalLendShares, uint256 interestEarnedAssets, uint256 feeRate)
        internal
        pure
        returns (uint256 feeShares)
    {
        feeShares = (interestEarnedAssets * feeRate * totalLendShares) / (Constants.FEE_PRECISION * (totalLendAssets + interestEarnedAssets));
    }

    /// @notice Gets the expected market balances after interest accrual.
    /// @return Updated market balances
    function getLastMarketState(IDahlia.Market memory market, uint256 lendAssets) internal view returns (IDahlia.Market memory) {
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 deltaTime = block.timestamp - market.updatedAt;
        if ((deltaTime != 0 || lendAssets != 0) && totalBorrowAssets != 0 && address(market.irm) != address(0)) {
            uint256 totalLendAssets = market.totalLendAssets + lendAssets;
            uint256 totalLendShares = market.totalLendShares;
            uint256 fullUtilizationRate = market.fullUtilizationRate;
            uint256 reserveFeeRate = market.reserveFeeRate;
            uint256 protocolFeeRate = market.protocolFeeRate;
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
