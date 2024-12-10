// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/// @title ManageMarketImpl library
/// @notice Implements market deployment and protocol fee
library ManageMarketImpl {
    function setProtocolFeeRate(IDahlia.Market storage market, uint256 newFee) internal {
        require(newFee != market.protocolFeeRate, Errors.AlreadySet());
        require(newFee <= Constants.MAX_FEE_RATE, Errors.MaxFeeExceeded());

        market.protocolFeeRate = uint24(newFee);
        emit IDahlia.SetProtocolFeeRate(market.id, newFee);
    }

    function setReserveFeeRate(IDahlia.Market storage market, uint256 newFee) internal {
        require(newFee != market.reserveFeeRate, Errors.AlreadySet());
        require(newFee <= Constants.MAX_FEE_RATE, Errors.MaxFeeExceeded());

        market.reserveFeeRate = uint24(newFee);
        emit IDahlia.SetReserveFeeRate(market.id, newFee);
    }

    function deployMarket(
        mapping(IDahlia.MarketId => IDahlia.MarketData) storage markets,
        IDahlia.MarketId id,
        IDahlia.MarketConfig memory marketConfig,
        IWrappedVault vault
    ) internal {
        IDahlia.Market storage market = markets[id].market;
        require(market.updatedAt == 0, Errors.MarketAlreadyDeployed());

        market.id = id;
        market.loanToken = marketConfig.loanToken;
        market.collateralToken = marketConfig.collateralToken;
        market.oracle = marketConfig.oracle;
        market.irm = marketConfig.irm;
        market.fullUtilizationRate = uint64(marketConfig.irm.minFullUtilizationRate());
        market.ratePerSec = uint64(marketConfig.irm.zeroUtilizationRate());
        market.lltv = uint24(marketConfig.lltv);
        market.updatedAt = uint48(block.timestamp);
        market.status = IDahlia.MarketStatus.Active;
        market.liquidationBonusRate = uint24(marketConfig.liquidationBonusRate);
        market.vault = vault;
        emit IDahlia.DeployMarket(id, vault, marketConfig);
    }
}
