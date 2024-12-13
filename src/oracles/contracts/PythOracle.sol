// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";

import { console } from "forge-std/Test.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title PythOracle
/// @notice A contract for fetching price from PythOracle
contract PythOracle is Ownable2Step, IDahliaOracle {
    using SafeCastLib for int64;
    using FixedPointMathLib for uint256;

    struct Params {
        address baseToken;
        bytes32 baseFeed;
        uint256 baseMaxDelay;
        address quoteToken;
        bytes32 quoteFeed;
        uint256 quoteMaxDelay;
    }

    Params public params;

    address public pythStaticOracle;

    uint256 public immutable ORACLE_PRECISION;

    /// @notice Initializes the contract with owner, oracle parameters, and Pyth static oracle address
    /// @param owner_ The address of the contract owner
    /// @param params_ The pyth oracle parameters
    /// @param pythStaticOracle_ The address of the Pyth static oracle
    constructor(address owner_, Params memory params_, address pythStaticOracle_) Ownable(owner_) {
        pythStaticOracle = pythStaticOracle_;
        params = params_;

        int64 baseTokenDecimals = SafeCastLib.toInt64(IERC20Metadata(params.baseToken).decimals());
        int64 quoteTokenDecimals = SafeCastLib.toInt64(IERC20Metadata(params.quoteToken).decimals());

        ORACLE_PRECISION =
            10 ** (36 + quoteTokenDecimals + getFeedDecimals(params.quoteFeed) - baseTokenDecimals - getFeedDecimals(params.baseFeed)).toUint256();
        console.log("ORACLE_PRECISION", ORACLE_PRECISION);
    }

    function getFeedDecimals(bytes32 feedId) internal returns (int64) {
        PythStructs.Price memory priceResult = IPyth(pythStaticOracle).getPriceUnsafe(feedId);
        return -priceResult.expo;
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256 price, bool isBadData) {
        PythStructs.Price memory basePrice = IPyth(pythStaticOracle).getPriceNoOlderThan(params.baseFeed, params.baseMaxDelay);
        PythStructs.Price memory quotePrice = IPyth(pythStaticOracle).getPriceNoOlderThan(params.quoteFeed, params.quoteMaxDelay);

        isBadData = false;
        price = ORACLE_PRECISION.mulDiv(basePrice.price.toUint256(), quotePrice.price.toUint256());
    }
}
