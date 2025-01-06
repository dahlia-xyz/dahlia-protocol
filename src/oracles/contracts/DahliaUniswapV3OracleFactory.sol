// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaUniswapV3Oracle } from "./DahliaUniswapV3Oracle.sol";
import { DahliaOracleFactoryBase } from "src/oracles/abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "src/oracles/abstracts/DahliaOracleStaticAddress.sol";

contract DahliaUniswapV3OracleFactory is DahliaOracleFactoryBase, DahliaOracleStaticAddress {
    /// @notice Emitted when a new Uniswap V3 oracle is created.
    event DahliaUniswapV3OracleCreated(address indexed caller, address indexed oracle);

    /// @notice Constructor sets the timelockAddress and uniswapStaticOracleAddress.
    /// @param timelock The address of the timelock.
    /// @param uniswapStaticOracle The address of a deployed UniswapV3 static oracle.
    constructor(address timelock, address uniswapStaticOracle) DahliaOracleFactoryBase(timelock) DahliaOracleStaticAddress(uniswapStaticOracle) { }

    /// @notice Deploys a new DahliaUniswapV3Oracle contract.
    /// @param params DahliaUniswapV3Oracle.OracleParams struct.
    /// @param twapDuration The TWAP duration in seconds.
    /// @return oracle The deployed DahliaUniswapV3Oracle contract instance.
    function createUniswapOracle(DahliaUniswapV3Oracle.Params memory params, uint32 twapDuration) external returns (DahliaUniswapV3Oracle oracle) {
        oracle = new DahliaUniswapV3Oracle(_TIMELOCK, params, _STATIC_ORACLE_ADDRESS, twapDuration);
        emit DahliaUniswapV3OracleCreated(msg.sender, address(oracle));
    }
}
