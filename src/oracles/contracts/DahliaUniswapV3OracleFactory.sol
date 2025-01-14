// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DahliaUniswapV3Oracle } from "./DahliaUniswapV3Oracle.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
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
        bytes memory encodedArgs = abi.encode(_TIMELOCK, params, _STATIC_ORACLE_ADDRESS, twapDuration);
        bytes32 salt = keccak256(encodedArgs);
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(DahliaUniswapV3Oracle).creationCode, encodedArgs));
        address expectedAddress = Create2.computeAddress(salt, initCodeHash);

        if (expectedAddress.code.length > 0) {
            oracle = DahliaUniswapV3Oracle(expectedAddress);
        } else {
            oracle = new DahliaUniswapV3Oracle{ salt: salt }(_TIMELOCK, params, _STATIC_ORACLE_ADDRESS, twapDuration);
            emit DahliaUniswapV3OracleCreated(msg.sender, address(oracle));
        }
    }
}
