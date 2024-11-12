// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IIrm {
    /// @notice Returns the current utilization rate
    /// @dev use it to set initial interest rate in the constructor
    function zeroUtilizationRate() external view returns (uint256);

    /// @notice Returns the rate in case of full market utilization
    /// @dev use it to set initial interest rate in case of 100% utilization
    function minFullUtilizationRate() external view returns (uint256);

    /// @notice name of Interest Rate Model
    function name() external view returns (string memory);

    /// @notice version of the Interest Rate Model
    /// @dev one digit number
    function version() external view returns (uint256);

    /// @notice Function calculates interest rates using two linear functions f(utilization)
    /// @param deltaTime The elapsed time since last update, given in seconds
    /// @param utilization The utilization %, given with 5 decimals of precision
    /// @param oldFullUtilizationRate The interest value when utilization is 100%, given with 18 decimals of precision
    /// @return newRatePerSec The new interest rate, 18 decimals of precision
    /// @return newFullUtilizationRate The new max interest rate, 18 decimals of precision
    function getNewRate(uint256 deltaTime, uint256 utilization, uint256 oldFullUtilizationRate)
        external
        view
        returns (uint256 newRatePerSec, uint256 newFullUtilizationRate);

    /// @notice calculate interest based on given elapsed seconds and utilization
    /// @param deltaTime elapsed time in seconds
    /// @param totalLendAssets total lend assets
    /// @param totalBorrowAssets total borrow assets
    /// @param oldFullUtilizationRate previous full utilization rate
    function calculateInterest(uint256 deltaTime, uint256 totalLendAssets, uint256 totalBorrowAssets, uint256 oldFullUtilizationRate)
        external
        view
        returns (uint256 interestEarnedAssets, uint256 newRatePerSec, uint256 newFullUtilizationRate);
}
