// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IChainlinkOracleWithMaxDelay {
    struct Delays {
        uint256 baseMaxDelayPrimary;
        uint256 baseMaxDelaySecondary;
        uint256 quoteMaxDelayPrimary;
        uint256 quoteMaxDelaySecondary;
    }

    // function maxDelays() external view returns (ChainlinkOracleMaxDelayParams memory maxDelays);

    /// @notice The ```setMaximumOracleDelays``` function sets the max oracle delay to determine if Chainlink data is stale
    /// @dev Requires msg.sender to be the timelock address
    /// @param _newMaxOracleDelays The new max oracle delay
    function setMaximumOracleDelays(Delays memory _newMaxOracleDelays) external;
}
