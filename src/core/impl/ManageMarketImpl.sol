// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {Types} from "src/core/types/Types.sol";

/**
 * @title ManageMarketImpl library
 * @notice Implements functions to validate the different actions of the protocol
 */
library ManageMarketImpl {
    using FixedPointMathLib for uint256;

    function setProtocolFeeRate(Types.Market storage market, uint256 newFee) internal {
        require(newFee != market.protocolFeeRate, Errors.AlreadySet());
        require(newFee <= Constants.MAX_FEE, Errors.MaxProtocolFeeExceeded());

        market.protocolFeeRate = uint24(newFee);
        emit Events.SetProtocolFeeRate(market.id, newFee);
    }

    function setReserveFeeRate(Types.Market storage market, uint256 newFee) internal {
        require(newFee != market.reserveFeeRate, Errors.AlreadySet());
        require(newFee <= Constants.MAX_FEE, Errors.MaxProtocolFeeExceeded());

        market.reserveFeeRate = uint24(newFee);
        emit Events.SetReserveFeeRate(market.id, newFee);
    }

    function deployMarket(
        mapping(Types.MarketId => Types.MarketData) storage markets,
        Types.MarketId id,
        Types.MarketConfig memory marketConfig
    ) internal {
        Types.Market storage market = markets[id].market;
        require(market.updatedAt == 0, Errors.MarketAlreadyDeployed());

        market.id = id;
        market.loanToken = marketConfig.loanToken;
        market.collateralToken = marketConfig.collateralToken;
        market.oracle = marketConfig.oracle;
        market.marketDeployer = msg.sender;
        market.irm = marketConfig.irm;
        market.lltv = uint24(marketConfig.lltv);
        market.rltv = uint24(marketConfig.rltv);
        market.updatedAt = uint48(block.timestamp);
        market.status = Types.MarketStatus.Active;
        market.liquidationBonusRate = uint24(marketConfig.liquidationBonusRate);
        market.reallocationBonusRate = uint24(MarketMath.calcReallocationBonusRate(market.lltv));
        emit Events.DeployMarket(id, marketConfig);
    }
}
