// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, Vm } from "@forge-std/Test.sol";
import { console } from "@forge-std/console.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { ERC20Mock as MockERC20 } from "test/common/mocks/ERC20Mock.sol";

contract Shiazinho is Test {
    using FixedPointMathLib for *;
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    WrappedVault testIncentivizedVault;
    WrappedVaultFactory testFactory;
    MockERC20 loanToken;
    MockERC20 collateralToken;
    Dahlia dahlia;

    uint256 constant DEFAULT_REFERRAL_FEE = 0.025e18;
    uint256 constant DEFAULT_FRONTEND_FEE = 0.025e18;
    uint256 constant DEFAULT_PROTOCOL_FEE = 0.05e18;

    address constant DEFAULT_FEE_RECIPIENT = address(0xdead);

    function setUp() public {
        ctx = new TestContext(vm);
        // change owner of vault to this test
        ctx.setWalletAddress("MARKET_DEPLOYER", address(this));
        // set default fee in dahliaRegistry
        dahlia = ctx.createDahlia();
        testFactory = ctx.createRoycoWrappedVaultFactory(dahlia, address(this), DEFAULT_FEE_RECIPIENT, DEFAULT_PROTOCOL_FEE, DEFAULT_FRONTEND_FEE);

        vm.startPrank(ctx.createWallet("OWNER"));
        dahlia.dahliaRegistry().setValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_INITIAL_FRONTEND_FEE, DEFAULT_FRONTEND_FEE);
        vm.stopPrank();

        loanToken = ctx.createERC20Token("USDC", 6);
        collateralToken = ctx.createERC20Token("WBTC", 18);

        IDahlia.MarketConfig memory marketConfig = IDahlia.MarketConfig({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: ctx.createTestOracle(1e36),
            irm: ctx.createTestIrm(),
            lltv: 9.5e4,
            liquidationBonusRate: 3.75e3,
            name: string.concat(loanToken.symbol(), "/", collateralToken.symbol(), " (", BoundUtils.toPercentString(9.5e4), "% LLTV)"),
            owner: address(this)
        });

        $ = ctx.bootstrapMarket(marketConfig);

        testIncentivizedVault = WrappedVault(address(dahlia.getMarket($.marketId).vault));
    }

    function test_shiazinho_borrowAndRepayDisableBorrowAttack(uint32 randomAmount) public {
        address[] memory lenders = new address[](10);
        uint256 amountToLend = 1e18;
        randomAmount = uint32(bound(randomAmount, 100, type(uint32).max));

        address[] memory borrowers = new address[](10);
        uint256 collateralAmount = 1e18;
        uint256 borrowAmount = 1;
        uint256 repayAmount = 1;

        for (uint256 i = 0; i < 10; i++) {
            lenders[i] = address(uint160(i + 11));
            loanToken.mint(lenders[i], amountToLend);
            vm.startPrank(lenders[i]);
            loanToken.approve(address(testIncentivizedVault), amountToLend);
            testIncentivizedVault.deposit(amountToLend, lenders[i]);
            vm.stopPrank();

            borrowers[i] = address(uint160(i + 21));
            collateralToken.mint(borrowers[i], collateralAmount);
            vm.startPrank(borrowers[i]);
            collateralToken.approve(address(dahlia), collateralAmount);
            dahlia.supplyCollateral($.marketId, collateralAmount, borrowers[i], "");
            //            dahlia.borrow($.marketId, randomAmount, borrowers[i], borrowers[i]);
            vm.stopPrank();
        }

        loanToken.mint(borrowers[0], 100);

        console.log("before: borrowShares[0]", dahlia.getPosition($.marketId, borrowers[0]).borrowShares);
        console.log("before: totalBorrowShares", dahlia.getMarket($.marketId).totalBorrowShares);
        console.log("before: totalBorrowAssets", dahlia.getMarket($.marketId).totalBorrowAssets);

        uint256 timesRunned;
        // if we do not proper rounding of rapay shares, we can brake the market
        while (dahlia.getMarket($.marketId).totalBorrowShares < type(uint128).max / 2) {
            vm.startPrank(borrowers[0]);
            dahlia.borrow($.marketId, borrowAmount, borrowers[0], borrowers[0]);
            loanToken.approve(address(dahlia), repayAmount);
            dahlia.repay($.marketId, 0, repayAmount, borrowers[0], "");
            vm.stopPrank();
            timesRunned++;
        }

        assertEq(timesRunned, 108);

        console.log("after: borrowShares[0]", dahlia.getPosition($.marketId, borrowers[0]).borrowShares);
        console.log("after: totalBorrowShares", dahlia.getMarket($.marketId).totalBorrowShares);
        console.log("after: totalBorrowAssets", dahlia.getMarket($.marketId).totalBorrowAssets);

        vm.startPrank(borrowers[1]);
        dahlia.borrow($.marketId, borrowAmount, borrowers[1], borrowers[1]);
        loanToken.approve(address(dahlia), repayAmount);
        dahlia.repay($.marketId, 0, $.dahlia.getPosition($.marketId, borrowers[1]).borrowShares, borrowers[1], "");
        vm.stopPrank();

        vm.prank(borrowers[2]);
        // if attack possible this test will fail
        vm.expectRevert();
        dahlia.borrow($.marketId, 1, borrowers[2], borrowers[2]);

        for (uint256 i = 0; i < 10; i++) {
            lenders[i] = address(uint160(i + 11));
            vm.startPrank(lenders[i]);
            testIncentivizedVault.redeem($.dahlia.getPosition($.marketId, lenders[i]).lendShares, lenders[i], lenders[i]);
            vm.stopPrank();
        }

        for (uint256 i = 0; i < 10; i++) {
            borrowers[i] = address(uint160(i + 21));
            console.log("after: borrowShares:", i, $.dahlia.getPosition($.marketId, borrowers[i]).borrowShares);
        }

        for (uint256 i = 2; i < 10; i++) {
            borrowers[i] = address(uint160(i + 21));
            vm.startPrank(borrowers[i]);
            dahlia.withdrawCollateral($.marketId, $.dahlia.getPosition($.marketId, borrowers[i]).collateral, borrowers[i], borrowers[i]);
            vm.stopPrank();
        }

        uint256 borrowShares = dahlia.getPosition($.marketId, borrowers[0]).borrowShares;
        console.log("borrowShares", borrowShares);
        vm.prank(borrowers[1]);
        vm.expectRevert();
        dahlia.liquidate($.marketId, borrowers[0], borrowShares, 0, "");
    }
}
