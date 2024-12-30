// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IPythOracle } from "../interfaces/IPythOracle.sol";

import { IPyth } from "@pyth/IPyth.sol";
import { PythStructs } from "@pyth/PythStructs.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";

/// @title PythOracleBase.sol
/// @notice Base contract for Pyth oracles
abstract contract PythOracleBase is IPythOracle {
    /// @dev Parameters for the oracle setup
    struct PythOracleParams {
        bytes32 priceFeedId; // Address of the price feed ID
        uint256 maxPriceAge; // Max age of the price in seconds
    }

    /// @notice Emitted when the contract is deployed
    /// @param priceFeedId The price feed ID
    event SetPriceFeedId(bytes32 priceFeedId);

    /// @notice Emitted when the contract is deployed
    /// @param pythStaticOracleAddress The address of the static Pyth oracle
    event SetPythStaticOracleAddress(address pythStaticOracleAddress);

    /// @notice Emitted when the max price age is updated
    /// @param oldMaxPriceAge The previous max oracle price age setting
    /// @param newMaxPriceAge The new max oracle price age setting
    event SetMaxPriceAge(uint256 oldMaxPriceAge, uint256 newMaxPriceAge);

    bytes32 public immutable PRICE_FEED_ID; // Address of the price feed ID
    address public immutable PYTH_STATIC_ORACLE_ADDRESS;
    uint256 public maxPriceAge; // Max age of the price in seconds

    constructor(PythOracleParams memory _params, address _pythStaticOracleAddress) {
        require(_params.priceFeedId != 0, Errors.ZeroAddress());

        PRICE_FEED_ID = _params.priceFeedId;
        emit SetPriceFeedId(PRICE_FEED_ID);
        PYTH_STATIC_ORACLE_ADDRESS = _pythStaticOracleAddress;
        emit SetPythStaticOracleAddress(PYTH_STATIC_ORACLE_ADDRESS);
        _setMaxPriceAge(_params.maxPriceAge);
    }

    /// @dev Internal function to update max price age
    /// @param _newMaxPriceAge The new max price age setting
    function _setMaxPriceAge(uint256 _newMaxPriceAge) internal {
        maxPriceAge = _newMaxPriceAge;
        emit SetMaxPriceAge(maxPriceAge, _newMaxPriceAge);
    }

    /// @notice External function to set new max price age
    /// @param _newMaxPriceAge The new max price age setting
    function setMaxPriceAge(uint256 _newMaxPriceAge) external virtual;

    /// @dev Internal function to get the Pyth price
    /// @return price for the token pair
    /// @return isBadData True if any of the data is stale or invalid
    function _getPythPrice() internal view returns (uint256 price, bool isBadData) {
        PythStructs.Price memory pythPrice = IPyth(PYTH_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(PRICE_FEED_ID, maxPriceAge);
        // TODO: Probably we need to check conf too
        price = uint256(uint64(pythPrice.price));
        isBadData = maxPriceAge != 0 && (pythPrice.price <= 0 || ((block.timestamp - pythPrice.publishTime) > maxPriceAge));
        //        // Remove exponent to avoid precision issues (price * 10^expo) and then multiply by 10^(-8)
        //        price = uint256((pythPrice.price * 10 ** pythPrice.expo) * 10 ** 8);
        //        price = uint256(pythPrice.price);
    }

    /// @inheritdoc IPythOracle
    function getMaxPriceAge() external view returns (uint256 _maxPriceAge) {
        return maxPriceAge;
    }
}
