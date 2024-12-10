// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IStaticOracle } from "@uniswap-v3-oracle/solidity/interfaces/IStaticOracle.sol";

import { Errors } from "src/oracles/helpers/Errors.sol";
import { IUniswapV3SingleTwapOracle } from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

/// @title UniswapOracleV3SingleTwapBase.sol
/// @notice A base contract for getting TWAP prices from Uniswap V3
abstract contract UniswapOracleV3SingleTwapBase is ERC165, IUniswapV3SingleTwapOracle {
    /// @dev Parameters for the oracle setup
    struct OracleParams {
        address uniswapV3PairAddress; // Address of the Uniswap V3 pair
        uint32 twapDuration; // Duration for the TWAP calculation
        address baseToken; // Base token address
        address quoteToken; // Quote token address
    }

    /// @dev Emitted when the TWAP duration is updated
    event SetTwapDuration(uint256 oldTwapDuration, uint256 newTwapDuration);

    /// @notice Emitted when the contract is deployed
    /// @param uniswapV3PairAddress Address of the Uniswap V3 pair
    /// @param baseToken Base token address
    /// @param quoteToken Quote token address
    /// @param uniswapStaticOracle Address of the static oracle
    event SetParams(address indexed uniswapV3PairAddress, address indexed baseToken, address indexed quoteToken, address uniswapStaticOracle);

    error TwapDurationIsTooShort();

    uint32 public constant MIN_TWAP_DURATION = 300;

    /// @notice Address of the Uniswap V3 pair
    address public immutable UNI_V3_PAIR_ADDRESS;

    /// @notice Precision used for TWAP calculations
    uint128 public constant TWAP_PRECISION = 1e36;

    /// @notice Base token used in the TWAP
    address public immutable UNISWAP_V3_TWAP_BASE_TOKEN;

    /// @notice Quote token used in the TWAP
    address public immutable UNISWAP_V3_TWAP_QUOTE_TOKEN;

    /// @notice Duration for the TWAP calculation
    uint32 public twapDuration;

    /// @notice Address of the static oracle used for TWAP
    address public immutable UNISWAP_STATIC_ORACLE_ADDRESS;

    /// @dev Constructor to initialize the oracle parameters
    /// @param _params Struct containing oracle parameters
    /// @param _uniswapStaticOracle Address of the static oracle
    constructor(OracleParams memory _params, address _uniswapStaticOracle) {
        UNI_V3_PAIR_ADDRESS = _params.uniswapV3PairAddress;
        _setTwapDuration(_params.twapDuration);
        UNISWAP_STATIC_ORACLE_ADDRESS = _uniswapStaticOracle;
        UNISWAP_V3_TWAP_BASE_TOKEN = _params.baseToken;
        UNISWAP_V3_TWAP_QUOTE_TOKEN = _params.quoteToken;
        emit SetParams(UNI_V3_PAIR_ADDRESS, UNISWAP_V3_TWAP_BASE_TOKEN, UNISWAP_V3_TWAP_QUOTE_TOKEN, UNISWAP_STATIC_ORACLE_ADDRESS);

        bool pairSupported = IStaticOracle(UNISWAP_STATIC_ORACLE_ADDRESS).isPairSupported(UNISWAP_V3_TWAP_BASE_TOKEN, UNISWAP_V3_TWAP_QUOTE_TOKEN);

        if (!pairSupported) revert Errors.PairNotSupported(UNISWAP_V3_TWAP_BASE_TOKEN, UNISWAP_V3_TWAP_QUOTE_TOKEN);
    }

    /// @dev Internal function to update the TWAP duration
    /// @param _newTwapDuration The new TWAP duration
    function _setTwapDuration(uint32 _newTwapDuration) internal {
        require(_newTwapDuration >= MIN_TWAP_DURATION, TwapDurationIsTooShort());
        emit SetTwapDuration({ oldTwapDuration: twapDuration, newTwapDuration: _newTwapDuration });
        twapDuration = _newTwapDuration;
    }

    /// @notice External function to set a new TWAP duration
    /// @param _newTwapDuration The new TWAP duration
    function setTwapDuration(uint32 _newTwapDuration) external virtual;

    /// @dev Internal function to get the TWAP price from Uniswap V3
    /// @return price The calculated TWAP price
    function _getUniswapV3Twap() internal view returns (uint256 price) {
        address[] memory _pools = new address[](1);
        _pools[0] = UNI_V3_PAIR_ADDRESS;

        price = IStaticOracle(UNISWAP_STATIC_ORACLE_ADDRESS).quoteSpecificPoolsWithTimePeriod({
            baseAmount: TWAP_PRECISION,
            baseToken: UNISWAP_V3_TWAP_BASE_TOKEN,
            quoteToken: UNISWAP_V3_TWAP_QUOTE_TOKEN,
            pools: _pools,
            period: twapDuration
        });
    }
}
