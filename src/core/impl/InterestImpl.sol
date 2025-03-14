// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "../../../lib/solady/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "../../../lib/solady/src/utils/SafeCastLib.sol";
import { IIrm } from "../../irm/interfaces/IIrm.sol";
import { Constants } from "../helpers/Constants.sol";
import { SharesMathLib } from "../helpers/SharesMathLib.sol";
import { IDahlia } from "../interfaces/IDahlia.sol";

/// @title InterestImpl library
/// @notice Implements protocol interest and fee accrual
library InterestImpl {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using SafeCastLib for uint256;

    /// @dev Accrues interest for the specified market.
    function executeMarketAccrueInterest(
        IDahlia.MarketId id,
        IDahlia.Market storage market,
        mapping(address => IDahlia.UserPosition) storage positions,
        address protocolFeeRecipient
    ) internal {
        uint256 deltaTime = block.timestamp - market.updatedAt;

        if (deltaTime == 0) return;

        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
            IIrm(market.irm).calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, market.fullUtilizationRate);

        market.fullUtilizationRate = uint64(newFullUtilizationRate);
        market.ratePerSec = uint64(newRatePerSec);

        totalLendAssets += interestEarnedAssets;

        uint256 protocolFeeAssets = interestEarnedAssets * market.protocolFeeRate / Constants.FEE_PRECISION;
        uint256 totalLendShares = market.totalLendShares;
        uint256 sumOfFeeAssets = protocolFeeAssets;
        uint256 sumOfFeeShares = sumOfFeeAssets.toSharesDown(totalLendAssets - sumOfFeeAssets, totalLendShares);

        totalLendShares += sumOfFeeShares;

        uint256 protocolFeeShares = protocolFeeAssets.toSharesDown(totalLendAssets, totalLendShares);

        if (protocolFeeShares > 0) {
            positions[protocolFeeRecipient].lendShares += protocolFeeShares.toUint128();
            market.vault.mintFees(protocolFeeShares, protocolFeeRecipient);
        }

        market.totalLendShares = totalLendShares;
        market.totalLendAssets = totalLendAssets;
        market.totalBorrowAssets = totalBorrowAssets + interestEarnedAssets;
        market.updatedAt = uint48(block.timestamp);

        emit IDahlia.AccrueInterest(id, newRatePerSec, newFullUtilizationRate, interestEarnedAssets, protocolFeeShares);
    }

    /// @notice Gets the expected market balances after interest accrual.
    /// @return Updated market balances
    function getLatestMarketState(IDahlia.Market memory market) internal view returns (IDahlia.Market memory) {
        uint256 deltaTime = block.timestamp - market.updatedAt;
        //we want to recompute ratePerSec and fullUtilizationRate for the last block to account changed totals
        //if (deltaTime == 0) return market;

        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate) =
            IIrm(market.irm).calculateInterest(deltaTime, totalLendAssets, totalBorrowAssets, market.fullUtilizationRate);

        market.fullUtilizationRate = uint64(newFullUtilizationRate);
        market.ratePerSec = uint64(newRatePerSec);

        totalLendAssets += interestEarnedAssets;

        uint256 protocolFeeAssets = interestEarnedAssets * market.protocolFeeRate / Constants.FEE_PRECISION;
        uint256 sumOfFeeAssets = protocolFeeAssets;
        uint256 sumOfFeeShares = sumOfFeeAssets.toSharesDown(totalLendAssets - sumOfFeeAssets, market.totalLendShares);

        market.totalLendShares += sumOfFeeShares;
        market.totalLendAssets = totalLendAssets;
        market.totalBorrowAssets = totalBorrowAssets + interestEarnedAssets;
        market.updatedAt = uint48(block.timestamp);
        return market;
    }
}
