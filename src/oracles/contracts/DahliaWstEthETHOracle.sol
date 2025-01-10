// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { AggregatorV3InterfaceLib } from "src/oracles/abstracts/AggregatorV3InterfaceLib.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title DahliaWstEthEthOracle
/// @notice Oracle to convert wstETH-ETH using a stETH-ETH Chainlink feed.
contract DahliaWstEthEthOracle is IDahliaOracle, Ownable2Step {
    using FixedPointMathLib for uint256;
    using AggregatorV3InterfaceLib for AggregatorV3Interface;

    struct Params {
        address wstEth;
        AggregatorV3Interface stEthToEthFeed;
    }

    struct Delays {
        uint256 stEthToEthMaxDelay;
    }

    event MaximumOracleDelayUpdated(Delays newMaxDelays);
    event ParamsUpdated(Params params);

    uint256 public immutable ORACLE_PRECISION;
    address public immutable WST_ETH;
    AggregatorV3Interface public immutable STETH_TO_ETH_FEED;

    uint256 internal stEthToEthMaxDelay;

    constructor(address owner, Params memory params, Delays memory delays) Ownable(owner) {
        require(params.wstEth != address(0), Errors.ZeroAddress());
        require(address(params.stEthToEthFeed) != address(0), Errors.ZeroAddress());

        WST_ETH = params.wstEth;
        STETH_TO_ETH_FEED = params.stEthToEthFeed;

        emit ParamsUpdated(params);
        _setMaximumOracleDelays(delays);

        // Precision scaling factor for prices
        ORACLE_PRECISION = 1e36;
    }

    function _setMaximumOracleDelays(Delays memory delays) private {
        emit MaximumOracleDelayUpdated({ newMaxDelays: delays });
        stEthToEthMaxDelay = delays.stEthToEthMaxDelay;
    }

    function setMaximumOracleDelays(Delays memory delays) external onlyOwner {
        _setMaximumOracleDelays(delays);
    }

    function maxDelays() external view returns (Delays memory) {
        return Delays({ stEthToEthMaxDelay: stEthToEthMaxDelay });
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view override returns (uint256, bool) {
        return _getWstEthInEth();
    }

    /// @dev Internal function to compute wstETH-ETH in e36 precision
    ///  1. Read stETH->ETH price from Chainlink feed
    ///  2. Cap the stETH->ETH price if necessary
    ///  3. Compute tokensPerStEth from wstETH
    ///  4. Compute price wstETH->ETH in e36 precision
    /// @return price The computed price
    /// @return isBadData Boolean indicating if the data is stale or invalid
    function _getWstEthInEth() internal view returns (uint256 price, bool isBadData) {
        (uint256 stEthToEthPrice, bool stEthToEthBad) = STETH_TO_ETH_FEED.getFeedPrice(stEthToEthMaxDelay);

        if (stEthToEthPrice > ORACLE_PRECISION) {
            stEthToEthPrice = ORACLE_PRECISION;
        }

        uint256 tokensPerStEth = IWstETH(WST_ETH).tokensPerStEth();
        isBadData = stEthToEthBad;

        uint256 wstEthInEth_1e18 = FixedPointMathLib.mulDiv(stEthToEthPrice, 1e18, tokensPerStEth);
        price = wstEthInEth_1e18 * 1e18; // Scale to e36 precision

        return (price, isBadData);
    }
}

interface IWstETH {
    function tokensPerStEth() external view returns (uint256);
}
