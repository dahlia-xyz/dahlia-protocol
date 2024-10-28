// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {
    ChainlinkOracleMaxDelayParams,
    ChainlinkOracleParams,
    ChainlinkWithMaxDelayBase
} from "src/oracles/abstracts/ChainlinkWithMaxDelayBase.sol";
import {IChainlinkOracleWithMaxDelay} from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import {IDahliaOracle} from "src/oracles/interfaces/IDahliaOracle.sol";

contract ChainlinkWithMaxDelay is ChainlinkWithMaxDelayBase, Ownable2Step, IDahliaOracle {
    constructor(address owner_, ChainlinkOracleParams memory params_, ChainlinkOracleMaxDelayParams memory _maxDelays)
        ChainlinkWithMaxDelayBase(params_, _maxDelays)
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

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256, bool) {
        return _getChainlinkPrice();
    }
}
