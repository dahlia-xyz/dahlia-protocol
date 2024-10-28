// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDahliaOracle} from "src/oracles/interfaces/IDahliaOracle.sol";

contract OracleMock is IDahliaOracle {
    uint256 public price;

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

    function getPrice() external view returns (uint256, bool) {
        return (price, false);
    }
}
