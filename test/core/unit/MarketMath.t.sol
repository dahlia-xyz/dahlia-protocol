// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Test} from "forge-std/Test.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {MarketMath} from "src/core/helpers/MarketMath.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";

contract MarketMathTest is Test {
    using MarketMath for uint256;
    using SharesMathLib for uint256;
    using Strings for uint256;

    struct MarketData {
        uint256 ta;
        uint256 ts;
        uint256 a;
        uint256 s;
        uint256 ra;
        uint256 rs;
    }

    MarketData[] internal mathSets;

    function processRateTest(function (MarketData memory, string memory) f) internal {
        uint256 length = mathSets.length;
        for (uint256 i = 0; i < length;) {
            f(mathSets[i], i.toString());
            i += 1;
        }
    }

    function test_unit_math_calcLiquidationBonusRate() public pure {
        uint256 C1 = Constants.LLTV_100_PERCENT / 100;
        assertEq(MarketMath.calcLiquidationBonusRate(99 * C1), 300); // 0.3%
        assertEq(MarketMath.calcLiquidationBonusRate(98 * C1), 603); // ~0.6%
        assertEq(MarketMath.calcLiquidationBonusRate(90 * C1), 3092); // ~3%
        assertEq(MarketMath.calcLiquidationBonusRate(80 * C1), 6382); // ~6.4%
        assertEq(MarketMath.calcLiquidationBonusRate(75 * C1), 8108); // ~8.1%
        assertEq(MarketMath.calcLiquidationBonusRate(60 * C1), Constants.MAX_LIQUIDATION_BONUS_RATE); // ~13.6% -> 10%
        assertEq(MarketMath.calcLiquidationBonusRate(50 * C1), Constants.MAX_LIQUIDATION_BONUS_RATE); // 15% -> 10%
    }

    function test_unit_math_calcReallocationBonusRate() public pure {
        uint256 C1 = Constants.LLTV_100_PERCENT / 100;
        assertEq(MarketMath.calcReallocationBonusRate(99 * C1), 100); // 0.1%
        assertEq(MarketMath.calcReallocationBonusRate(98 * C1), 200); // 0.2%
        assertEq(MarketMath.calcReallocationBonusRate(90 * C1), 1010); // ~1%
        assertEq(MarketMath.calcReallocationBonusRate(80 * C1), 2040); // ~2.04%
        assertEq(MarketMath.calcReallocationBonusRate(75 * C1), 2564); // ~2.564%
        assertEq(MarketMath.calcReallocationBonusRate(60 * C1), Constants.MAX_REALLOCATION_BONUS_RATE); // ~4.166
        assertEq(MarketMath.calcReallocationBonusRate(50 * C1), Constants.MAX_REALLOCATION_BONUS_RATE);
    }

    function test_unit_math_lend() public {
        delete mathSets;
        mathSets.push(MarketData(0, 0, 1, 0, 1, SharesMathLib.SHARES_OFFSET));
        mathSets.push(MarketData(0, 0, 0, SharesMathLib.SHARES_OFFSET, 1, 0));
        mathSets.push(MarketData(100, 100 * SharesMathLib.SHARES_OFFSET, 0, SharesMathLib.SHARES_OFFSET, 1, 0));
        mathSets.push(MarketData(1000, 100 * SharesMathLib.SHARES_OFFSET, 1, 0, 1, 100899));
        processRateTest(validate_lend);
    }

    function validate_lend(MarketData memory s, string memory index) internal pure {
        uint256 shares = SharesMathLib.toSharesDown(s.a, s.ta, s.ts);
        assertEq(shares, s.rs, index);
    }

    function test_math_getPositiontLtv() public pure {
        assertEq(MarketMath.getLTV(2000, 1000, 10e36), 0.2e5); // 20% LTV
        assertEq(MarketMath.getLTV(1000, 2000, 10e36), 0.05e5); // 5% LTV
        assertEq(MarketMath.getLTV(1000, 2000, 1e36), 0.5e5); // 50% LTV
        assertEq(MarketMath.getLTV(2000, 2000, 1e36), 1e5); // 100% LTV
        assertEq(MarketMath.getLTV(4000, 2000, 1e36), 2e5); // 200% LTV
    }
    // todo add more tests for math
}
