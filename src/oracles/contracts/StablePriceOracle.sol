// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title StablePriceOracle
/// @notice A contract that return always permanent price
contract StablePriceOracle is IDahliaOracle {
    uint256 internal immutable _price;

    constructor(uint256 price_) {
        _price = price_;
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256, bool) {
        return (_price, false);
    }
}
