// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "../../../lib/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "../../../lib/pyth-sdk-solidity/PythStructs.sol";
import { FixedPointMathLib } from "../../../lib/solady/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "../../../lib/solady/src/utils/SafeCastLib.sol";
import { DahliaOracleStaticAddress } from "../abstracts/DahliaOracleStaticAddress.sol";
import { Errors } from "../helpers/Errors.sol";
import { IDahliaOracle } from "../interfaces/IDahliaOracle.sol";

/// @title DahliaPythV2Oracle
/// @notice A contract for fetching price from Pyth Oracle
contract DahliaPythV2Oracle is Ownable2Step, IDahliaOracle, DahliaOracleStaticAddress {
    using SafeCastLib for *;
    using FixedPointMathLib for uint256;

    /// @notice Emitted when the contract is deployed
    /// @param params Initial parameters
    event ParamsUpdated(Params params);

    /// @notice Emitted when the max oracle delay is updated
    /// @param oldMaxDelays The previous max oracle delay settings
    /// @param newMaxDelays The new max oracle delay settings
    event MaximumOracleDelaysUpdated(Delays oldMaxDelays, Delays newMaxDelays);

    uint256 public immutable ORACLE_PRECISION; // 32 bytes

    address public immutable BASE_TOKEN_PRIMARY; // 20 bytes
    address public immutable QUOTE_TOKEN_PRIMARY; // 20 bytes

    bytes32 public immutable BASE_FEED_PRIMARY; // 32 bytes
    bytes32 public immutable BASE_FEED_SECONDARY; // 32 bytes
    bytes32 public immutable QUOTE_FEED_PRIMARY; // 32 bytes
    bytes32 public immutable QUOTE_FEED_SECONDARY; // 32 bytes
    uint256 public baseMaxDelayPrimary; // 32 bytes
    uint256 public baseMaxDelaySecondary; // 32 bytes
    uint256 public quoteMaxDelayPrimary; // 32 bytes
    uint256 public quoteMaxDelaySecondary; // 32 bytes

    struct Params {
        address baseToken;
        bytes32 baseFeedPrimary;
        bytes32 baseFeedSecondary;
        address quoteToken;
        bytes32 quoteFeedPrimary;
        bytes32 quoteFeedSecondary;
    }

    /// @notice Struct to hold max delay settings
    struct Delays {
        uint256 baseMaxDelayPrimary;
        uint256 baseMaxDelaySecondary;
        uint256 quoteMaxDelayPrimary;
        uint256 quoteMaxDelaySecondary;
    }

    /// @notice Initializes the contract with owner, oracle parameters, and Pyth static oracle address
    /// @param owner The address of the contract owner
    /// @param params The pyth oracle parameters
    /// @param staticOracleAddress The address of the Pyth static oracle
    constructor(address owner, Params memory params, Delays memory delays, address staticOracleAddress)
        Ownable(owner)
        DahliaOracleStaticAddress(staticOracleAddress)
    {
        BASE_TOKEN_PRIMARY = params.baseToken;
        BASE_FEED_PRIMARY = params.baseFeedPrimary;
        BASE_FEED_SECONDARY = params.baseFeedSecondary;
        QUOTE_TOKEN_PRIMARY = params.quoteToken;
        QUOTE_FEED_PRIMARY = params.quoteFeedPrimary;
        QUOTE_FEED_SECONDARY = params.quoteFeedSecondary;

        emit ParamsUpdated(params);
        _setMaximumOracleDelays(delays);

        int32 baseTokenDecimals = getDecimals(params.baseToken); // 95434 354543 * 10^-8
        int32 quoteTokenDecimals = getDecimals(params.quoteToken);
        uint256 precision = (
            36 + quoteTokenDecimals - getFeedExpo(params.quoteFeedPrimary) - getFeedExpo(params.quoteFeedSecondary) + getFeedExpo(params.baseFeedPrimary)
                + getFeedExpo(params.baseFeedSecondary) - baseTokenDecimals
        ).toUint256();

        ORACLE_PRECISION = 10 ** precision;
    }

    function getDecimals(address token) internal view returns (int32) {
        return (IERC20Metadata(token).decimals()).toInt32();
    }

    function getFeedExpo(bytes32 feedId) internal view returns (int32) {
        if (feedId == bytes32(0)) {
            return 0; // Return 0 if feed is zero
        }
        return IPyth(_STATIC_ORACLE_ADDRESS).getPriceUnsafe(feedId).expo;
    }

    function _getFeedPrice(bytes32 feed, uint256 maxDelay) internal view returns (uint256 price) {
        if (feed == bytes32(0)) {
            return 1; // Return default price if feed address is zero
        }

        PythStructs.Price memory result = IPyth(_STATIC_ORACLE_ADDRESS).getPriceNoOlderThan(feed, maxDelay);
        require(result.price >= 0, Errors.NegativeAnswer(result.price)); // Ensure the answer is non-negative

        // Determine if the data is stale or negative
        price = result.price.toUint256();
    }
    /// @inheritdoc IDahliaOracle

    function getPrice() external view returns (uint256 price, bool isBadData) {
        uint256 basePricePrimary = _getFeedPrice(BASE_FEED_PRIMARY, baseMaxDelayPrimary);
        uint256 basePriceSecondary = _getFeedPrice(BASE_FEED_SECONDARY, baseMaxDelaySecondary);
        uint256 quotePricePrimary = _getFeedPrice(QUOTE_FEED_PRIMARY, quoteMaxDelayPrimary);
        uint256 quotePriceSecondary = _getFeedPrice(QUOTE_FEED_SECONDARY, quoteMaxDelaySecondary);

        price = ORACLE_PRECISION.mulDiv(basePricePrimary * basePriceSecondary, quotePricePrimary * quotePriceSecondary);
        isBadData = price == 0;
    }

    /// @dev Internal function to update max oracle delays
    function _setMaximumOracleDelays(Delays memory delays) internal {
        emit MaximumOracleDelaysUpdated({
            oldMaxDelays: Delays({
                baseMaxDelayPrimary: baseMaxDelayPrimary,
                baseMaxDelaySecondary: baseMaxDelaySecondary,
                quoteMaxDelayPrimary: quoteMaxDelayPrimary,
                quoteMaxDelaySecondary: quoteMaxDelaySecondary
            }),
            newMaxDelays: delays
        });
        baseMaxDelayPrimary = delays.baseMaxDelayPrimary;
        baseMaxDelaySecondary = delays.baseMaxDelaySecondary;
        quoteMaxDelayPrimary = delays.quoteMaxDelayPrimary;
        quoteMaxDelaySecondary = delays.quoteMaxDelaySecondary;
    }

    /// @notice Set new max oracle delays
    /// @param delays The new max delay settings
    function setMaximumOracleDelays(Delays memory delays) external onlyOwner {
        _setMaximumOracleDelays(delays);
    }
}
