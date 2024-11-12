// SPDX-License-Identifier: ISC
pragma solidity ^0.8.27;

// Adapted from https://github.com/FraxFinance/fraxlend/

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

/// @title A formula for calculating interest rates as a function of utilization and time
/// @notice A Contract for calculating interest rates as a function of utilization and time
contract VariableIrm is IIrm {
    struct Config {
        /// @notice The minimum utilization wherein no adjustment to the full utilization and target rates occurs
        /// @dev Is smaller than targetUtilization,
        /// example 0.75 * Constants.UTILIZATION_100_PERCENT
        uint256 minTargetUtilization;
        /// @notice The maximum utilization wherein no adjustment to the full utilization and vertex rates occurs
        /// @dev Is larger than targetUtilization
        /// example 0.85 * Constants.UTILIZATION_100_PERCENT
        uint256 maxTargetUtilization;
        /// @notice The utilization at which the slope of the IR curve increases
        /// example 0.85 * Constants.UTILIZATION_100_PERCENT
        uint256 targetUtilization;
        /// @notice The interest rate half life in seconds, determines the speed at which the IR curve adjusts to over and under-utilization
        /// At a 100% utilization, the full_utilization_rate, and hence the target rate too, doubles at this rate
        /// At a 0% utilization, the full_utilization_rate, and hence the target rate too, halves at this rate
        /// example 172800, 2 days
        /// @dev max supported value is 194.18 days
        uint256 rateHalfLife;
        // Interest Rate Settings (all rates are per second), 365.24 days per year
        /// @notice The minimum interest rate (per second) when utilization is 100%
        /// example 1582470460, (~5% yearly) 18 decimals
        uint256 minFullUtilizationRate;
        /// @notice The maximum interest rate (per second) when utilization is 100%
        /// example 3164940920000, (~10000% yearly) 18 decimals
        uint256 maxFullUtilizationRate;
        /// @notice The interest rate (per second) when utilization is 0%
        /// example 158247046, (~0.5% yearly) 18 decimals
        uint256 zeroUtilizationRate;
        /// @notice The percent of the delta between the full utilization rate and the zeroUtilizationRate
        /// example 0.2e18, 18 decimals
        uint256 targetRatePercent;
    }

    using FixedPointMathLib for uint256;

    uint256 public immutable minFullUtilizationRate;
    uint256 public immutable maxFullUtilizationRate;
    // TODO: make uint64
    uint256 public immutable zeroUtilizationRate;
    uint256 public immutable targetRatePercent;
    uint24 public immutable minTargetUtilization;
    uint24 public immutable maxTargetUtilization;
    uint24 public immutable targetUtilization;
    uint24 public immutable rateHalfLife;

    /// @param _config variable interest rate parameters
    constructor(Config memory _config) {
        minFullUtilizationRate = _config.minFullUtilizationRate;
        maxFullUtilizationRate = _config.maxFullUtilizationRate;
        zeroUtilizationRate = _config.zeroUtilizationRate;
        targetRatePercent = _config.targetRatePercent;
        minTargetUtilization = uint24(_config.minTargetUtilization);
        maxTargetUtilization = uint24(_config.maxTargetUtilization);
        targetUtilization = uint24(_config.targetUtilization);
        rateHalfLife = uint24(_config.rateHalfLife);
    }

    /// @inheritdoc IIrm
    function name() external pure returns (string memory) {
        return string(abi.encodePacked("Dahlia Variable Interest Rate"));
    }

    /// @inheritdoc IIrm
    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice Function calculate the new maximum interest rate, i.e. rate when utilization is 100%
    /// @dev Given in interest per second
    /// @param deltaTime The elapsed time since last update given in seconds
    /// @param utilization The utilization %, given with 5 decimals of precision
    /// @param fullUtilizationRate The interest value when utilization is 100%, given with 18 decimals of precision
    /// @return newFullUtilizationRate The new maximum interest rate
    function getFullUtilizationInterest(uint256 deltaTime, uint256 utilization, uint256 fullUtilizationRate)
        internal
        view
        returns (uint256 newFullUtilizationRate)
    {
        uint256 _minTargetUtilization = minTargetUtilization;
        uint256 _maxTargetUtilization = maxTargetUtilization;
        uint256 _maxFullUtilizationRate = maxFullUtilizationRate;
        uint256 _minFullUtilizationRate = minFullUtilizationRate;

        if (utilization < _minTargetUtilization) {
            uint256 _rateHalfLife = rateHalfLife;
            uint256 _deltaUtilization = _minTargetUtilization - utilization;
            // 36 decimals
            uint256 _decayGrowth = _rateHalfLife + (_deltaUtilization * _deltaUtilization * deltaTime / _minTargetUtilization / _minTargetUtilization);
            // 18 decimals
            newFullUtilizationRate = (fullUtilizationRate * _rateHalfLife) / _decayGrowth;
        } else if (utilization > _maxTargetUtilization) {
            uint256 _rateHalfLife = rateHalfLife;
            uint256 _leftUtilization = IrmConstants.UTILIZATION_100_PERCENT - _maxTargetUtilization;
            uint256 _deltaUtilization = utilization - _maxTargetUtilization;
            // 36 decimals
            uint256 _decayGrowth = _rateHalfLife + (_deltaUtilization * _deltaUtilization * deltaTime) / _leftUtilization / _leftUtilization;
            // 18 decimals
            newFullUtilizationRate = (fullUtilizationRate * _decayGrowth) / _rateHalfLife;
        } else {
            newFullUtilizationRate = fullUtilizationRate;
        }
        return newFullUtilizationRate.min(_maxFullUtilizationRate).max(_minFullUtilizationRate);
    }

    /// @inheritdoc IIrm
    function getNewRate(uint256 deltaTime, uint256 utilization, uint256 oldFullUtilizationRate)
        external
        view
        returns (uint256 newRatePerSec, uint256 newFullUtilizationRate)
    {
        return _getNewRate(deltaTime, utilization, oldFullUtilizationRate);
    }

    function _getNewRate(uint256 deltaTime, uint256 utilization, uint256 oldFullUtilizationRate)
        internal
        view
        returns (uint256 newRatePerSec, uint256 newFullUtilizationRate)
    {
        uint256 _zeroUtilizationRate = zeroUtilizationRate;
        uint256 _targetUtilization = targetUtilization;

        newFullUtilizationRate = getFullUtilizationInterest(deltaTime, utilization, oldFullUtilizationRate);

        // _targetRate is calculated as the percentage of the delta between min and max interest
        uint256 _targetRate = _zeroUtilizationRate + FixedPointMathLib.mulWad(newFullUtilizationRate - _zeroUtilizationRate, targetRatePercent);

        if (utilization < _targetUtilization) {
            // For readability, the following formula is equivalent to:
            // slope = ((_targetRate - zeroUtilizationRate) * Constants.UTILIZATION_100_PERCENT) / targetUtilization;
            // newRatePerSec = uint64(zeroUtilizationRate + ((utilization * slope) / Constants.UTILIZATION_100_PERCENT));

            // 18 decimals
            newRatePerSec = _zeroUtilizationRate + (utilization * (_targetRate - _zeroUtilizationRate)) / _targetUtilization;
        } else {
            // For readability, the following formula is equivalent to:
            // slope = (((_newFullUtilizationInterest - _targetRate) * Constants.UTILIZATION_100_PERCENT) / (Constants.UTILIZATION_100_PERCENT -
            // _targetUtilization));
            // newRatePerSec = uint64(_targetRate + (((_utilization - _targetUtilization) * slope) / Constants.UTILIZATION_100_PERCENT));

            // 18 decimals
            newRatePerSec = _targetRate
                + ((utilization - _targetUtilization) * (newFullUtilizationRate - _targetRate)) / (IrmConstants.UTILIZATION_100_PERCENT - _targetUtilization);
        }
    }

    /// @inheritdoc IIrm
    function calculateInterest(uint256 deltaTime, uint256 totalLendAssets, uint256 totalBorrowAssets, uint256 fullUtilizationRate)
        external
        view
        returns (uint256 _interestEarnedAssets, uint256 _newRatePerSec, uint256 _newFullUtilizationRate)
    {
        // Get the utilization rate
        uint256 _utilizationRate = totalLendAssets == 0 ? 0 : (IrmConstants.UTILIZATION_100_PERCENT * totalBorrowAssets) / totalLendAssets;

        // Request new interest rate and full utilization rate from the rate calculator
        (_newRatePerSec, _newFullUtilizationRate) = _getNewRate(deltaTime, _utilizationRate, fullUtilizationRate);

        // Calculate interest accrued
        _interestEarnedAssets = (deltaTime * totalBorrowAssets * _newRatePerSec) / FixedPointMathLib.WAD;
    }
}
