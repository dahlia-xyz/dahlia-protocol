// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ChainlinkOracleWithMaxDelayBase } from "src/oracles/abstracts/ChainlinkOracleWithMaxDelayBase.sol";
import { IChainlinkOracleWithMaxDelay } from "src/oracles/interfaces/IChainlinkOracleWithMaxDelay.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title ChainlinkOracleWithMaxDelay
/// @notice A contract that extends ChainlinkOracleWithMaxDelayBase.sol with ownership and oracle functionality
contract ChainlinkOracleWithMaxDelay is ChainlinkOracleWithMaxDelayBase, Ownable2Step, IDahliaOracle {
    /// @notice Constructor to initialize the contract with owner, parameters, and max delays
    /// @param owner_ The address of the contract owner
    /// @param params_ The parameters for the oracle
    /// @param _maxDelays The maximum delay settings for the oracle
    constructor(address owner_, Params memory params_, Delays memory _maxDelays) ChainlinkOracleWithMaxDelayBase(params_, _maxDelays) Ownable(owner_) { }

    /// @inheritdoc IChainlinkOracleWithMaxDelay
    function setMaximumOracleDelays(Delays memory _newMaxOracleDelays) external override onlyOwner {
        _setMaximumOracleDelays(_newMaxOracleDelays);
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256, bool) {
        return _getChainlinkPrice();
    }
}
