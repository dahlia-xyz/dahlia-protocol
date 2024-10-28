// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    ChainlinkOracleMaxDelayParams,
    ChainlinkOracleParams,
    ChainlinkWithMaxDelayBase
} from "src/oracles/abstracts/ChainlinkWithMaxDelayBase.sol";
import {UniswapOraclerParams, UniswapV3SingleTwapBase} from "src/oracles/abstracts/UniswapV3SingleTwapBase.sol";
import {IChainlinkOracleWithMaxDelay} from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import {IDahliaOracle} from "src/oracles/interfaces/IDahliaOracle.sol";
import {IUniswapV3SingleTwapOracle} from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

contract DualOracleChainlinkUniV3 is ChainlinkWithMaxDelayBase, UniswapV3SingleTwapBase, Ownable2Step, IDahliaOracle {
    constructor(
        address owner_,
        ChainlinkOracleParams memory chainlinkParams,
        ChainlinkOracleMaxDelayParams memory chainlinkMaxDelays,
        UniswapOraclerParams memory uniswapParams,
        address uniswapStaticOracle
    )
        ChainlinkWithMaxDelayBase(chainlinkParams, chainlinkMaxDelays)
        UniswapV3SingleTwapBase(uniswapParams, uniswapStaticOracle)
        Ownable(owner_)
    {}

    /// @inheritdoc IChainlinkOracleWithMaxDelay
    function setMaximumOracleDelays(ChainlinkOracleMaxDelayParams memory _newMaxOracleDelays)
        external
        override
        onlyOwner
    {
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
