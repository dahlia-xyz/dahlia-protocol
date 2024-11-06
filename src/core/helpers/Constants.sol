// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library Constants {
    uint256 internal constant LLTV_100_PERCENT = 1e5;

    uint256 internal constant FEE_PRECISION = 1e5;

    /// @dev The maximum fee a market can have (25%).
    uint256 internal constant MAX_FEE_RATE = 0.25e5;

    /// @dev Oracle price scale.
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;

    /// @dev Minimal LLTV range.
    uint24 internal constant DEFAULT_MIN_LLTV_RANGE = uint24(1 * Constants.LLTV_100_PERCENT / 100);

    /// @dev Maximum LLTV range.
    uint24 internal constant DEFAULT_MAX_LLTV_RANGE = uint24(99 * Constants.LLTV_100_PERCENT / 100);

    /// @dev Max liquidation bonus rate.
    uint256 internal constant DEFAULT_MIN_LIQUIDATION_BONUS_RATE = uint24(1);

    /// @dev Max liquidation bonus rate.
    uint256 internal constant DEFAULT_MAX_LIQUIDATION_BONUS_RATE = uint24(15 * Constants.LLTV_100_PERCENT / 100);

    /// @dev Max reallocation bonus rate.
    uint256 internal constant MAX_REALLOCATION_BONUS_RATE = 4 * Constants.LLTV_100_PERCENT / 100;

    /// @dev `Dahlia` contract address position in DahliaRegistry.
    uint256 internal constant ADDRESS_ID_DAHLIA = 1;

    /// @dev `DahliaProvider` contract address position in DahliaRegistry.
    uint256 internal constant ADDRESS_ID_DAHLIA_PROVIDER = 2;

    /// @dev `OracleFactory` contract address position in DahliaRegistry.
    uint256 internal constant ADDRESS_ID_ORACLE_FACTORY = 4;

    /// @dev `IRMFactory` contract address position in DahliaRegistry.
    uint256 internal constant ADDRESS_ID_IRM_FACTORY = 5;

    /// @dev `RoycoERC4626IFactory` contract address position in DahliaRegistry.
    uint256 internal constant ADDRESS_ID_ROYCO_ERC4626I_FACTORY = 10;

    /// @dev `initialFrontendFee` value position in DahliaRegistry.
    uint256 internal constant VALUE_ID_ROYCO_ERC4626I_FACTORY_MIN_INITIAL_FRONTEND_FEE = 10;
}
