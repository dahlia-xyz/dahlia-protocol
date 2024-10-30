// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "@forge-std/Test.sol";
import {TestConstants} from "test/common/TestConstants.sol";
import {TestContext} from "test/common/TestContext.sol";
import {TestTypes} from "test/common/TestTypes.sol";
import {ERC20Mock, IERC20} from "test/common/mocks/ERC20Mock.sol";

library DahliaTransUtils {
    function dahliaLendBy(Vm vm, address lender, uint256 assets, TestContext.MarketContext memory $) internal {
        ERC20Mock($.marketConfig.loanToken).setBalance(lender, assets);

        vm.startPrank(lender);
        IERC20($.marketConfig.loanToken).approve(address($.dahlia), assets);
        $.dahlia.lend($.marketId, assets, lender, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();
    }

    function dahliaBorrowBy(Vm vm, address borrower, uint256 assets, TestContext.MarketContext memory $) internal {
        vm.prank(borrower);
        $.dahlia.borrow($.marketId, assets, 0, borrower, borrower);
    }

    function dahliaRepayBy(Vm vm, address borrower, uint256 assets, TestContext.MarketContext memory $) internal {
        vm.startPrank(borrower);
        IERC20($.marketConfig.loanToken).approve(address($.dahlia), assets);
        $.dahlia.repay($.marketId, assets, 0, borrower, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();
    }

    function dahliaSupplyCollateralBy(Vm vm, address lender, uint256 assets, TestContext.MarketContext memory $)
        internal
    {
        ERC20Mock($.marketConfig.collateralToken).setBalance(lender, assets);
        vm.startPrank(lender);
        IERC20($.marketConfig.collateralToken).approve(address($.dahlia), assets);
        $.dahlia.supplyCollateral($.marketId, assets, lender, TestConstants.EMPTY_CALLBACK);
        vm.stopPrank();
    }

    function dahliaSubmitPosition(
        Vm vm,
        TestTypes.MarketPosition memory pos,
        address lender,
        address borrower,
        TestContext.MarketContext memory $
    ) internal {
        $.oracle.setPrice(type(uint256).max / pos.collateral);
        dahliaLendBy(vm, lender, pos.lent, $);
        dahliaSupplyCollateralBy(vm, borrower, pos.collateral, $);
        dahliaBorrowBy(vm, borrower, pos.borrowed, $);
        $.oracle.setPrice(pos.price);
    }

    function dahliaPrepareLoanBalanceFor(Vm vm, address liquidator, uint256 amount, TestContext.MarketContext memory $)
        internal
    {
        $.loanToken.setBalance(liquidator, amount);
        vm.prank(liquidator);
        $.loanToken.approve(address($.dahlia), amount);
    }

    function dahliaPrepareCollateralBalanceFor(
        Vm vm,
        address liquidator,
        uint256 amount,
        TestContext.MarketContext memory $
    ) internal {
        $.collateralToken.setBalance(liquidator, amount);
        vm.prank(liquidator);
        $.collateralToken.approve(address($.dahlia), amount);
    }
}
