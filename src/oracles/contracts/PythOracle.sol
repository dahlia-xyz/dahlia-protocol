// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title PythOracle
/// @notice A contract for fetching price from PythOracle
contract PythOracle is Ownable2Step, IDahliaOracle {
    using SafeCastLib for *;
    using FixedPointMathLib for uint256;

    address public immutable pythStaticOracle; // 20 bytes
    uint256 public immutable ORACLE_PRECISION;

    address public immutable baseToken; // 20 bytes
    address public immutable quoteToken; // 20 bytes
    bytes32 public immutable baseFeed; // 32 bytes
    bytes32 public immutable quoteFeed; // 32 bytes
    uint256 public immutable baseMaxDelay; // 32 bytes
    uint256 public immutable quoteMaxDelay; // 32 bytes

    struct Params {
        address baseToken;
        bytes32 baseFeed;
        uint256 baseMaxDelay;
        address quoteToken;
        bytes32 quoteFeed;
        uint256 quoteMaxDelay;
    }

    /// @notice Initializes the contract with owner, oracle parameters, and Pyth static oracle address
    /// @param owner The address of the contract owner
    /// @param params The pyth oracle parameters
    /// @param oracle The address of the Pyth static oracle
    constructor(address owner, Params memory params, address oracle) Ownable(owner) {
        pythStaticOracle = oracle;
        baseToken = params.baseToken;
        baseFeed = params.baseFeed;
        baseMaxDelay = params.baseMaxDelay;
        quoteToken = params.quoteToken;
        quoteFeed = params.quoteFeed;
        quoteMaxDelay = params.quoteMaxDelay;

        int32 baseTokenDecimals = getDecimals(params.baseToken);
        int32 quoteTokenDecimals = getDecimals(params.quoteToken);
        uint256 precision = (quoteTokenDecimals + getFeedDecimals(params.baseFeed) - getFeedDecimals(params.quoteFeed) - baseTokenDecimals).toUint256();

        ORACLE_PRECISION = 10 ** (36 + precision);
    }

    function getDecimals(address token) internal returns (int32) {
        return (IERC20Metadata(token).decimals()).toInt32();
    }

    function getFeedDecimals(bytes32 feedId) internal returns (int32) {
        return IPyth(pythStaticOracle).getPriceUnsafe(feedId).expo;
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256 price, bool isBadData) {
        PythStructs.Price memory basePrice = IPyth(pythStaticOracle).getPriceNoOlderThan(baseFeed, baseMaxDelay);
        PythStructs.Price memory quotePrice = IPyth(pythStaticOracle).getPriceNoOlderThan(quoteFeed, quoteMaxDelay);

        price = ORACLE_PRECISION.mulDiv(basePrice.price.toUint256(), quotePrice.price.toUint256());
        isBadData = price == 0;
    }
}
