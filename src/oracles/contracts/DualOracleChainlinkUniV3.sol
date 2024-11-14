// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ChainlinkOracleWithMaxDelayBase } from "src/oracles/abstracts/ChainlinkOracleWithMaxDelayBase.sol";
import { UniswapOracleV3SingleTwapBase } from "src/oracles/abstracts/UniswapOracleV3SingleTwapBase.sol";
import { IChainlinkOracleWithMaxDelay } from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { IUniswapV3SingleTwapOracle } from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

/// @title DualOracleChainlinkUniV3
/// @notice Dual oracle with Chainlink and Uniswap V3 price feeds
contract DualOracleChainlinkUniV3 is ChainlinkOracleWithMaxDelayBase, UniswapOracleV3SingleTwapBase, Ownable2Step, IDahliaOracle {
    /// @notice Initializes the contract with owner, Chainlink, and Uniswap parameters
    /// @param owner_ The address of the contract owner
    /// @param chainlinkParams Parameters for Chainlink oracle
    /// @param chainlinkMaxDelays Max delay settings for Chainlink oracle
    /// @param uniswapParams Parameters for Uniswap V3 TWAP oracle
    /// @param uniswapStaticOracle Address of the Uniswap static oracle
    constructor(address owner_, Params memory chainlinkParams, Delays memory chainlinkMaxDelays, OracleParams memory uniswapParams, address uniswapStaticOracle)
        ChainlinkOracleWithMaxDelayBase(chainlinkParams, chainlinkMaxDelays)
        UniswapOracleV3SingleTwapBase(uniswapParams, uniswapStaticOracle)
        Ownable(owner_)
    { }

    /// @inheritdoc IChainlinkOracleWithMaxDelay
    function setMaximumOracleDelays(Delays memory _newMaxOracleDelays) external override onlyOwner {
        _setMaximumOracleDelays(_newMaxOracleDelays);
    }

    /// @inheritdoc IUniswapV3SingleTwapOracle
    function setTwapDuration(uint32 _newTwapDuration) external override onlyOwner {
        _setTwapDuration(_newTwapDuration);
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256, bool) {
        (uint256 _chainlinkPrice, bool _chainlinkIsBadPrice) = _getChainlinkPrice();
        uint256 _uniswapPrice = _getUniswapV3Twap();
        uint256 _minPrice = (!_chainlinkIsBadPrice && _chainlinkPrice < _uniswapPrice) ? _chainlinkPrice : _uniswapPrice;
        return (_minPrice, false);
    }
}
