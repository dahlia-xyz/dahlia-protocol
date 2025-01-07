// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Vm } from "@forge-std/Test.sol";
import { console } from "@forge-std/console.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { DahliaTest } from "test/common/abstracts/DahliaTest.sol";

contract CartioTest is DahliaTest {
    using SharesMathLib for *;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;
    using FixedPointMathLib for uint256;

    TestContext ctx;
    TestContext.MarketContext $;

    function setUp() public {
        vm.createSelectFork("cartio", 3_792_585);
        ctx = new TestContext(vm);
    }

    function _getMaxBorrowableAmount(IDahlia.Market memory market, IDahlia.UserPosition memory position, uint256 additionalCollateral)
        internal
        view
        returns (uint256 borrowedAssets, uint256 borrowableAssets, uint256 collateralPrice)
    {
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        borrowedAssets = position.borrowShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 positionCapacity = MarketMath.calcMaxBorrowAssets(collateralPrice, position.collateral + additionalCollateral, market.lltv);
        console.log("positionCapacity", positionCapacity);
        uint256 leftToBorrow = positionCapacity > borrowedAssets ? positionCapacity - borrowedAssets : 0;
        console.log("leftToBorrow", leftToBorrow);
        uint256 availableLendAssets = market.totalLendAssets - market.totalBorrowAssets;
        console.log("availableLendAssets", availableLendAssets);
        borrowableAssets = availableLendAssets.min(leftToBorrow);
    }

    /// run with `forge test -vv --mt test_cartio_getMaxBorrowableAmount`
    function test_cartio_getMaxBorrowableAmount() public {
        IDahlia dahlia = IDahlia(0x0A7e67A977cf9aB1DE3781Ec58625010050E446E);
        IDahlia.MarketId id = IDahlia.MarketId.wrap(1);
        IDahlia.Market memory market = dahlia.getMarket(id);
        console.log("totalBorrowAssets", market.totalBorrowAssets);
        address user = 0xd940909AE50e084706e479604BAe660b5F932E18;
        IDahlia.UserPosition memory position = dahlia.getPosition(id, user);
        (uint256 borrowedAssets, uint256 borrowableAssets, uint256 collateralPrice) = _getMaxBorrowableAmount(market, position, 0);
        console.log("borrowedAssets", borrowedAssets);
        console.log("borrowableAssets", borrowableAssets);
        console.log("collateralPrice", collateralPrice);
    }
}
