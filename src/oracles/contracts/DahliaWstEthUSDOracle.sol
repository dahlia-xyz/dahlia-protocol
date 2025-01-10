// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { AggregatorV3InterfaceLib } from "src/oracles/abstracts/AggregatorV3InterfaceLib.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title DahliaWstEthUsdOracle
/// @notice Oracle to convert wstETH-USD using stETH-ETH and ETH-USD Chainlink feeds.
contract DahliaWstEthUsdOracle is IDahliaOracle, Ownable2Step {
    using FixedPointMathLib for uint256;
    using AggregatorV3InterfaceLib for AggregatorV3Interface;

    struct Params {
        address wstEth;
        AggregatorV3Interface stEthToEthFeed;
        AggregatorV3Interface ethToUsdFeed;
    }

    struct Delays {
        uint256 stEthToEthMaxDelay;
        uint256 ethToUsdMaxDelay;
    }

    event MaximumOracleDelayUpdated(Delays newMaxDelays);
    event ParamsUpdated(Params params);

    address public immutable WST_ETH;
    AggregatorV3Interface public immutable STETH_TO_ETH_FEED;
    AggregatorV3Interface public immutable ETH_TO_USD_FEED;

    uint256 public immutable ORACLE_PRECISION;
    uint256 public immutable PRICE_CAP;

    uint256 internal stEthToEthMaxDelay;
    uint256 internal ethToUsdMaxDelay;

    constructor(address owner, Params memory params, Delays memory delays, uint256 priceCap) Ownable(owner) {
        require(params.wstEth != address(0), Errors.ZeroAddress());
        require(address(params.stEthToEthFeed) != address(0), Errors.ZeroAddress());
        require(address(params.ethToUsdFeed) != address(0), Errors.ZeroAddress());

        WST_ETH = params.wstEth;
        STETH_TO_ETH_FEED = params.stEthToEthFeed;
        ETH_TO_USD_FEED = params.ethToUsdFeed;

        PRICE_CAP = priceCap;

        emit ParamsUpdated(params);
        _setMaximumOracleDelays(delays);

        ORACLE_PRECISION = 1e36;
    }

    function _setMaximumOracleDelays(Delays memory delays) private {
        emit MaximumOracleDelayUpdated({ newMaxDelays: delays });
        stEthToEthMaxDelay = delays.stEthToEthMaxDelay;
        ethToUsdMaxDelay = delays.ethToUsdMaxDelay;
    }

    function setMaximumOracleDelays(Delays memory delays) external onlyOwner {
        _setMaximumOracleDelays(delays);
    }

    function maxDelays() external view returns (Delays memory) {
        return Delays({ stEthToEthMaxDelay: stEthToEthMaxDelay, ethToUsdMaxDelay: ethToUsdMaxDelay });
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view override returns (uint256, bool) {
        return _getWstEthInUsd();
    }

    /// @dev Internal function to compute wstETH-USD in e36 precision.
    /// @return price The computed price
    /// @return isBadData Boolean indicating if the data is stale or invalid
    function _getWstEthInUsd() internal view returns (uint256 price, bool isBadData) {
        // 1. Get stETH->ETH price
        (uint256 stEthToEthPrice, bool stEthBad) = STETH_TO_ETH_FEED.getFeedPrice(stEthToEthMaxDelay);

        // 2. Cap stETH->ETH price if it exceeds PRICE_CAP
        if (stEthToEthPrice > PRICE_CAP) {
            stEthToEthPrice = PRICE_CAP;
        }

        // 3. Get ETH->USD price
        (uint256 ethToUsdPrice, bool ethUsdBad) = ETH_TO_USD_FEED.getFeedPrice(ethToUsdMaxDelay);

        // 4. Get tokensPerStEth
        uint256 tokensPerStEth = IWstETH(WST_ETH).tokensPerStEth();

        // 5. Determine if data is bad
        isBadData = stEthBad || ethUsdBad;

        // 6. Compute wstETH->ETH (in 1e18 scale)
        uint256 wstEthInEth_1e18 = FixedPointMathLib.mulDiv(stEthToEthPrice, 1e18, tokensPerStEth);

        // 7. Convert ETH value to USD (still 1e18 scale)
        uint256 wstEthInUsd_1e18 = FixedPointMathLib.mulDiv(wstEthInEth_1e18, ethToUsdPrice, 1e18);

        // 8. Scale to e36 precision
        price = wstEthInUsd_1e18 * 1e18;

        return (price, isBadData);
    }
}

interface IWstETH {
    function tokensPerStEth() external view returns (uint256);
}
