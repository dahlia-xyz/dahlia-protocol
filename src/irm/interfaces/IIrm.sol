// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// TODO: document this
interface IIrm {
    function zeroUtilizationRate() external view returns (uint256);
    function minFullUtilizationRate() external view returns (uint256);

    function name() external view returns (string memory);

    function version() external view returns (uint256);

    function getNewRate(uint256 _deltaTime, uint256 _u, uint256 _maxInterest)
        external
        view
        returns (uint256 _newRatePerSec, uint256 _newMaxInterest);

    function calculateInterest(
        uint256 deltaTime,
        uint256 totalLendAssets,
        uint256 totalBorrowAssets,
        uint256 fullUtilizationRate
    ) external view returns (uint256 _interestEarnedAssets, uint256 _newRatePerSec, uint256 _newFullUtilizationRate);
}
