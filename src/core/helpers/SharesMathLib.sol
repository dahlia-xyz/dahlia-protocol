// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";

/// @title SharesMathLib
/// @dev : The implication is based on solady and uniswap
/// lib/solady/src/tokens/ERC4626.sol
/// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
library SharesMathLib {
    using FixedPointMathLib for uint256;

    uint256 internal constant SHARES_OFFSET = 1e6;

    /// @dev Calculates the value of `assets` quoted in shares, rounding down.
    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDiv(totalShares + SHARES_OFFSET, totalAssets + 1);
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding down.
    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDiv(totalAssets + 1, totalShares + SHARES_OFFSET);
    }

    /// @dev Calculates the value of `assets` quoted in shares, rounding up.
    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDivUp(totalShares + SHARES_OFFSET, totalAssets + 1);
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding up.
    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDivUp(totalAssets + 1, totalShares + SHARES_OFFSET);
    }
}
