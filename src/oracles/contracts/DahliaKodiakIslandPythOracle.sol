// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "../../../lib/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "../../../lib/pyth-sdk-solidity/PythStructs.sol";
import { FixedPointMathLib } from "../../../lib/solady/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "../../../lib/solady/src/utils/SafeCastLib.sol";
import { DahliaOracleStaticAddress } from "../abstracts/DahliaOracleStaticAddress.sol";
import { IDahliaOracle } from "../interfaces/IDahliaOracle.sol";

/// @notice Minimal interface for the KodiakIsland.
interface IKodiakIsland {
    function getUnderlyingBalances() external view returns (uint256, uint256);
    function totalSupply() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function pool() external view returns (address);
    function mint(uint256 mintAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted);
    function burn(uint256 burnAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
    function getAvgPrice(uint32 interval) external view returns (uint160 avgSqrtPriceX96);
}

interface IKodiakUniswapV3PoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );
}

/// @title KodiakIslandPythOracle
/// @notice An oracle that returns the price of one KodiakIsland vault token in terms of a specified ERC20 token,
/// using Pyth feeds for the underlying tokens.
/// @dev The vault's underlying value is computed as:
///      (underlying0 * price0_in_quote + underlying1 * price1_in_quote) / totalSupply
contract DahliaKodiakIslandPythOracle is Ownable2Step, IDahliaOracle, DahliaOracleStaticAddress {
    using SafeCastLib for *;
    using FixedPointMathLib for uint256;

    /// @notice Emitted when the contract is deployed
    /// @param params Initial parameters
    event ParamsUpdated(Params params);
    /// @notice Emitted when the max oracle delay is updated
    /// @param oldMaxDelays The previous max oracle delay settings
    /// @param newMaxDelays The new max oracle delay settings
    event MaximumOracleDelaysUpdated(Delays oldMaxDelays, Delays newMaxDelays);

    /// @dev Emitted when the TWAP duration is updated
    event TwapDurationUpdated(uint256 oldTwapDuration, uint256 newTwapDuration);
    /// @dev Emitted when the slippage percentage is updated
    event SlippagePercentageUpdated(uint256 oldSlippagePercentage, uint256 newSlippagePercentage);

    error TwapDurationIsTooShort();
    error SlippagePercentageIsTooHigh();

    uint32 public constant MIN_TWAP_DURATION = 10;

    // Maximum threshold constant set to 10% (100% - 1e5).
    uint32 public constant MAX_SLIPPAGE_PERCENT = 1e4;

    // These conversion factors convert each underlying token's price (from its Pyth feed)
    // into QUOTE_TOKEN terms.
    uint256 public immutable ORACLE_PRECISION_TOKEN0;
    uint256 public immutable ORACLE_PRECISION_TOKEN1;

    // The vault (KodiakIsland) whose shares we want to price.
    address public immutable KODIAK_ISLAND; // 20 bytes
    address public immutable QUOTE_TOKEN; // 20 bytes
    // Pyth feed IDs for the underlying tokens.
    bytes32 public immutable BASE_TOKEN0_FEED; // 32 bytes
    bytes32 public immutable BASE_TOKEN1_FEED; // 32 bytes
    // Pyth feed ID for the QUOTE token.
    bytes32 public immutable QUOTE_FEED; // 20 bytes

    // Maximum acceptable delays for price data (in seconds)
    uint256 public baseToken0MaxDelay; // 32 bytes
    uint256 public baseToken1MaxDelay; // 32 bytes
    uint256 public quoteMaxDelay; // 32 bytes

    // TWAP duration
    uint32 public twapDuration;
    // Deviation in percents between the TWAP price and current price
    uint32 public slippagePercentage;

    /// @notice Oracle configuration parameters.
    struct Params {
        address kodiakIsland;
        bytes32 baseToken0Feed;
        bytes32 baseToken1Feed;
        address quoteToken;
        bytes32 quoteFeed;
    }

    /// @notice Maximum delay settings for each feed.
    struct Delays {
        uint256 baseToken0MaxDelay;
        uint256 baseToken1MaxDelay;
        uint256 quoteMaxDelay;
    }

    /// @notice Initializes the contract with owner, oracle parameters, and Pyth static oracle address
    /// @param owner The address of the contract owner
    /// @param params The pyth oracle parameters
    /// @param delays Maximum allowed delays for base, and quote feed data
    /// @param staticOracleAddress The address of the Pyth static oracle
    /// @param duration TWAP duration in seconds
    /// @param slippage TWAP slippage percentage
    constructor(address owner, Params memory params, Delays memory delays, address staticOracleAddress, uint32 duration, uint32 slippage)
        Ownable(owner)
        DahliaOracleStaticAddress(staticOracleAddress)
    {
        KODIAK_ISLAND = params.kodiakIsland;
        QUOTE_TOKEN = params.quoteToken;
        BASE_TOKEN0_FEED = params.baseToken0Feed;
        BASE_TOKEN1_FEED = params.baseToken1Feed;
        QUOTE_FEED = params.quoteFeed;

        _setTwapDuration(duration);
        _setSlippagePercentage(slippage);

        emit ParamsUpdated(params);
        _setMaximumOracleDelays(delays);

        // Get underlying token addresses from the vault.
        address token0Addr = IKodiakIsland(params.kodiakIsland).token0();
        address token1Addr = IKodiakIsland(params.kodiakIsland).token1();
        // Get decimals from ERC20 metadata.
        int32 token0Decimals = getDecimals(token0Addr);
        int32 token1Decimals = getDecimals(token1Addr);
        int32 quoteDecimals = getDecimals(params.quoteToken);

        // Get "expo" from Pyth feeds.
        int32 token0FeedExpo = getFeedDecimals(params.baseToken0Feed);
        int32 token1FeedExpo = getFeedDecimals(params.baseToken1Feed);
        int32 quoteFeedExpo = getFeedDecimals(params.quoteFeed);

        // Compute conversion precision for each underlying token.
        // Formula: precision = 36 + quoteDecimals + tokenFeedExpo - quoteFeedExpo - tokenDecimals.
        uint256 precision0 = (36 + quoteDecimals + token0FeedExpo - quoteFeedExpo - token0Decimals).toUint256();
        uint256 precision1 = (36 + quoteDecimals + token1FeedExpo - quoteFeedExpo - token1Decimals).toUint256();

        ORACLE_PRECISION_TOKEN0 = 10 ** precision0;
        ORACLE_PRECISION_TOKEN1 = 10 ** precision1;
    }

    function getDecimals(address token) internal view returns (int32) {
        return (IERC20Metadata(token).decimals()).toInt32();
    }

    /// @notice Returns the exponent ("decimal") from a Pyth feed.
    /// @param feedId The feed identifier.
    function getFeedDecimals(bytes32 feedId) internal view returns (int32) {
        return IPyth(_STATIC_ORACLE_ADDRESS).getPriceUnsafe(feedId).expo;
    }

    /// @dev Internal function to update the TWAP duration
    /// @param newTwapDuration The new TWAP duration
    function _setTwapDuration(uint32 newTwapDuration) internal {
        require(newTwapDuration >= MIN_TWAP_DURATION, TwapDurationIsTooShort());
        emit TwapDurationUpdated({ oldTwapDuration: twapDuration, newTwapDuration: newTwapDuration });
        twapDuration = newTwapDuration;
    }

    /// @notice Set a new TWAP duration for the Uniswap V3 TWAP oracle
    /// @dev Only callable by the timelock address
    /// @param newTwapDuration The new TWAP duration in seconds
    function setTwapDuration(uint32 newTwapDuration) external onlyOwner {
        _setTwapDuration(newTwapDuration);
    }

    /// @dev Internal function to update the slippage percentage
    /// @param newSlippagePercentage The new slippage percentage
    function _setSlippagePercentage(uint32 newSlippagePercentage) internal {
        require(newSlippagePercentage <= MAX_SLIPPAGE_PERCENT, SlippagePercentageIsTooHigh());
        emit SlippagePercentageUpdated({ oldSlippagePercentage: slippagePercentage, newSlippagePercentage: newSlippagePercentage });
        slippagePercentage = newSlippagePercentage;
    }

    function setSlippagePercentage(uint32 newSlippagePercentage) external onlyOwner {
        _setSlippagePercentage(newSlippagePercentage);
    }

    function _isBadData(uint256 price) internal view returns (bool isBadData) {
        IKodiakIsland kodiakIsland = IKodiakIsland(KODIAK_ISLAND);
        uint160 avgSqrtPriceX96 = kodiakIsland.getAvgPrice(twapDuration);
        IKodiakUniswapV3PoolState pool = IKodiakUniswapV3PoolState(kodiakIsland.pool());
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Calculate the absolute difference between current and average prices
        int256 diff = avgSqrtPriceX96.toInt256() - sqrtPriceX96.toInt256();
        uint256 absDiff = FixedPointMathLib.abs(diff);

        // Compute the deviation percentage.
        // Note: Multiplying diff by 10000 to express as a percentage.
        uint256 deviationPercentage = (absDiff * 1e5) / uint256(uint160(avgSqrtPriceX96));

        isBadData = (deviationPercentage > slippagePercentage) || (price == 0);
    }

    /// @inheritdoc IDahliaOracle
    /// @notice Returns the price of one vault token (share) in terms of QUOTE_TOKEN.
    /// The computation is:
    ///   price = (underlying0 * price0_in_quote + underlying1 * price1_in_quote) / totalSupply
    /// where each priceX_in_quote is computed from Pyth data.
    function getPrice() external view returns (uint256 price, bool isBadData) {
        // Get Pyth prices for token0, token1, and the quote token.
        PythStructs.Price memory token0Price = IPyth(_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(BASE_TOKEN0_FEED, baseToken0MaxDelay);
        PythStructs.Price memory token1Price = IPyth(_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(BASE_TOKEN1_FEED, baseToken1MaxDelay);
        PythStructs.Price memory quotePrice = IPyth(_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(QUOTE_FEED, quoteMaxDelay);

        // Convert each underlying token's price to QUOTE_TOKEN terms.
        uint256 priceUSDToken0InQuote = ORACLE_PRECISION_TOKEN0.mulDiv(token0Price.price.toUint256(), quotePrice.price.toUint256());
        uint256 priceUSDToken1InQuote = ORACLE_PRECISION_TOKEN1.mulDiv(token1Price.price.toUint256(), quotePrice.price.toUint256());

        IKodiakIsland kodiakIsland = IKodiakIsland(KODIAK_ISLAND);

        // Get the vault's current underlying balances and total supply.
        (uint256 underlying0, uint256 underlying1) = kodiakIsland.getUnderlyingBalances();
        uint256 totalVaultSupply = kodiakIsland.totalSupply();
        require(totalVaultSupply > 0, "Vault supply is zero");

        // Compute total underlying value in QUOTE_TOKEN terms.
        uint256 totalUSDValueInQuote = underlying0 * priceUSDToken0InQuote + underlying1 * priceUSDToken1InQuote;

        // Price per vault token (share).
        price = totalUSDValueInQuote / totalVaultSupply;

        isBadData = _isBadData(price);
    }

    /// @dev Internal function to update maximum oracle delays.
    function _setMaximumOracleDelays(Delays memory delays) internal {
        emit MaximumOracleDelaysUpdated(
            Delays({ baseToken0MaxDelay: baseToken0MaxDelay, baseToken1MaxDelay: baseToken1MaxDelay, quoteMaxDelay: quoteMaxDelay }), delays
        );
        baseToken0MaxDelay = delays.baseToken0MaxDelay;
        baseToken1MaxDelay = delays.baseToken1MaxDelay;
        quoteMaxDelay = delays.quoteMaxDelay;
    }

    /// @notice Allows the owner to update the maximum oracle delays.
    /// @param delays The new delay settings.
    function setMaximumOracleDelays(Delays memory delays) external onlyOwner {
        _setMaximumOracleDelays(delays);
    }
}
