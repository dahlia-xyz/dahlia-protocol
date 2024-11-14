// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { UniswapOracleV3SingleTwapBase } from "src/oracles/abstracts/UniswapOracleV3SingleTwapBase.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { IUniswapV3SingleTwapOracle } from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

/// @title UniswapOracleV3SingleTwap
/// @notice A contract for fetching TWAP from Uniswap V3
contract UniswapOracleV3SingleTwap is UniswapOracleV3SingleTwapBase, Ownable2Step, IDahliaOracle {
    /// @notice Initializes the contract with owner, oracle parameters, and Uniswap static oracle address
    /// @param owner_ The address of the contract owner
    /// @param params_ The oracle parameters
    /// @param uniswapStaticOracle_ The address of the Uniswap static oracle
    constructor(address owner_, OracleParams memory params_, address uniswapStaticOracle_)
        UniswapOracleV3SingleTwapBase(params_, uniswapStaticOracle_)
        Ownable(owner_)
    { }

    /// @inheritdoc IUniswapV3SingleTwapOracle
    function setTwapDuration(uint32 _newTwapDuration) external override onlyOwner {
        _setTwapDuration(_newTwapDuration);
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256 price, bool isBadData) {
        price = _getUniswapV3Twap();
        isBadData = false;
    }
}
