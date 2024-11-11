// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Errors } from "src/oracles/helpers/Errors.sol";

library AggregatorV3InterfaceLib {
    function getFeedPrice(AggregatorV3Interface feed, uint256 maxDelay) internal view returns (uint256 price, bool isBadData) {
        if (address(feed) == address(0)) {
            return (1, false);
        }

        (, int256 _answer,, uint256 _chainlinkUpdatedAt,) = feed.latestRoundData();
        require(_answer >= 0, Errors.NegativeAnswer(_answer));

        // If data is stale or negative, set bad data to true and return
        isBadData = maxDelay != 0 && (_answer <= 0 || ((block.timestamp - _chainlinkUpdatedAt) > maxDelay));
        price = uint256(_answer);
    }

    function getDecimals(AggregatorV3Interface feed) internal view returns (uint256) {
        if (address(feed) == address(0)) {
            return 0;
        }
        return feed.decimals();
    }
}
