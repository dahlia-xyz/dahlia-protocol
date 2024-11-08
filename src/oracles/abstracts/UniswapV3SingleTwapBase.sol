// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IStaticOracle} from "@uniswap-v3-oracle/solidity/interfaces/IStaticOracle.sol";
import {IUniswapV3SingleTwapOracle} from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

/// @title UniswapV3SingleTwapBase
/// @notice  An oracle for UniV3 Twap prices
abstract contract UniswapV3SingleTwapBase is ERC165, IUniswapV3SingleTwapOracle {
    struct OracleParams {
        address uniswapV3PairAddress;
        uint32 twapDuration;
        address baseToken;
        address quoteToken;
    }

    event SetTwapDuration(uint256 oldTwapDuration, uint256 newTwapDuration);

    /// @notice address of the Uniswap V3 pair
    address public immutable UNI_V3_PAIR_ADDRESS;

    /// @notice The precision of the twap
    uint128 public constant TWAP_PRECISION = 1e36;

    /// @notice The base token of the twap
    address public immutable UNISWAP_V3_TWAP_BASE_TOKEN;

    /// @notice The quote token of the twap
    address public immutable UNISWAP_V3_TWAP_QUOTE_TOKEN;

    /// @notice The duration of the twap
    uint32 public twapDuration;
    address public immutable UNISWAP_STATIC_ORACLE_ADDRESS;

    constructor(OracleParams memory _params, address _uniswapStaticOracle) {
        UNI_V3_PAIR_ADDRESS = _params.uniswapV3PairAddress;
        twapDuration = _params.twapDuration;
        UNISWAP_STATIC_ORACLE_ADDRESS = _uniswapStaticOracle;
        UNISWAP_V3_TWAP_BASE_TOKEN = _params.baseToken;
        UNISWAP_V3_TWAP_QUOTE_TOKEN = _params.quoteToken;
    }

    /// @notice The ```_setTwapDuration``` function sets duration of the twap
    /// @param _newTwapDuration The new twap duration
    function _setTwapDuration(uint32 _newTwapDuration) internal {
        emit SetTwapDuration({oldTwapDuration: twapDuration, newTwapDuration: _newTwapDuration});
        twapDuration = _newTwapDuration;
    }

    function setTwapDuration(uint32 _newTwapDuration) external virtual;

    /// @notice The ```_getUniswapV3Twap``` function is called to get the twap
    /// @return price The twap price
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
