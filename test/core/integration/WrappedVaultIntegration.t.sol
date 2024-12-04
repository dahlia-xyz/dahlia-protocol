// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestConstants, TestContext } from "test/common/TestContext.sol";
import { TestTypes } from "test/common/TestTypes.sol";

contract WrappedVaultIntegration is Test {
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    IERC4626 marketProxy;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv());
        marketProxy = IERC4626(address($.dahlia.getMarket($.marketId).vault));
    }

    function test_int_proxy_checks() public view {
        assertEq(marketProxy.decimals(), 12);
        assertEq(marketProxy.asset(), $.marketConfig.loanToken);
    }

    function test_int_proxy_name() public {
        TestContext.MarketContext memory ctx2 = ctx.bootstrapMarket("USDC", "WBTC", 81 * Constants.LLTV_100_PERCENT / 100);
        assertEq(IDahlia.MarketId.unwrap(ctx2.marketId), 2);
        assertEq(IERC4626(address(ctx2.dahlia.getMarket(ctx2.marketId).vault)).name(), "USDC/WBTC (81% LLTV)");
        TestContext.MarketContext memory ctx3 = ctx.bootstrapMarket("USDC", "WBTC", 815 * Constants.LLTV_100_PERCENT / 1000);
        assertEq(IDahlia.MarketId.unwrap(ctx3.marketId), 3);
        assertEq(IERC4626(address(ctx3.dahlia.getMarket(ctx3.marketId).vault)).name(), "USDC/WBTC (81.5% LLTV)");
    }

    function test_int_proxy_depositByAssets(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        uint256 expectedLendShares = assets.toSharesDown(0, 0);

        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.bob);
        assertEq(shares, expectedLendShares);
        assertEq(userPos.lendShares, shares);

        assertEq(marketProxy.balanceOf($.alice), 0, "alice balance");
        assertEq(marketProxy.balanceOf($.bob), shares, "bob balance");
        assertEq(marketProxy.maxWithdraw($.bob), assets, "bob max withdraw");
        assertEq(marketProxy.totalAssets(), assets, "total assets");
        assertEq(
            marketProxy.totalSupply(),
            shares,
            /**
             * + 10_000e6*
             */
            "total supply"
        );
    }

    function test_int_proxy_depositByShares(uint256 shares) public {
        vm.pauseGasMetering();
        shares = vm.boundShares(shares);
        uint256 assets = shares.toAssetsUp(0, 0);
        // need to cut random shares till X000000 type
        shares = assets.toSharesDown(0, 0);

        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        vm.resumeGasMetering();
        uint256 resAssets = marketProxy.mint(shares, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.bob);
        assertEq(assets, resAssets);
        assertEq(userPos.lendShares, shares);

        assertEq(marketProxy.balanceOf($.alice), 0);
        assertEq(marketProxy.balanceOf($.bob), shares);
        assertEq(marketProxy.maxWithdraw($.bob), assets);
        assertEq(marketProxy.totalAssets(), assets);
        assertEq(marketProxy.totalSupply(), shares /*+ 10_000e6*/ );
    }

    function test_int_proxy_withdrawByAssets(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        uint256 expectedLendShares = assets.toSharesDown(0, 0);

        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.expectEmit(true, true, true, true, address(marketProxy));
        emit IWrappedVault.Withdraw($.bob, $.alice, $.bob, assets, shares);
        vm.resumeGasMetering();
        uint256 sharesWithdrawn = marketProxy.withdraw(assets, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.bob);
        assertEq(shares, sharesWithdrawn);
        assertEq(shares, expectedLendShares);
        assertEq(userPos.lendShares, 0);

        assertEq($.loanToken.balanceOf($.alice), assets);
        assertEq(marketProxy.balanceOf($.alice), 0);
        assertEq(marketProxy.balanceOf($.bob), 0);
        assertEq(marketProxy.totalAssets(), 0);
        assertEq(marketProxy.totalSupply(), 0 /*10_000e6*/ );
    }

    function test_int_proxy_withdrawByShares(uint256 shares) public {
        vm.pauseGasMetering();
        shares = vm.boundShares(shares);
        uint256 assets = shares.toAssetsUp(0, 0);
        // need to cut random shares till X000000 type
        shares = assets.toSharesDown(0, 0);

        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        vm.resumeGasMetering();
        uint256 resAssets = marketProxy.mint(shares, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.expectEmit(true, true, true, true, address(marketProxy));
        emit IWrappedVault.Withdraw($.bob, $.alice, $.bob, assets, shares);
        vm.resumeGasMetering();
        uint256 assetsRedeemed = marketProxy.redeem(shares, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.UserPosition memory userPos = $.dahlia.getPosition($.marketId, $.bob);
        assertEq(resAssets, assets);
        assertEq(assetsRedeemed, assets);
        assertEq(userPos.lendShares, 0);
        assertEq($.loanToken.balanceOf($.alice), assets);
        assertEq(marketProxy.balanceOf($.alice), 0);
        assertEq(marketProxy.balanceOf($.bob), 0);
        assertEq(marketProxy.totalAssets(), 0);
        assertEq(marketProxy.totalSupply(), 0 /*10_000e6*/ );
    }

    function test_int_proxy_revertWithdrawNoApprove(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        marketProxy.deposit(assets, $.alice);
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.resumeGasMetering();
        vm.expectRevert(WrappedVault.NotOwnerOfVaultOrApproved.selector);
        marketProxy.withdraw(assets, $.bob, $.alice);
        vm.stopPrank();
    }

    function test_int_proxy_revertWithdrawNotEnoughAssetsOnDahlia(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        marketProxy.deposit(assets, $.alice);
        vm.stopPrank();

        vm.startPrank($.alice);
        vm.expectRevert();
        vm.resumeGasMetering();
        marketProxy.withdraw(assets + 1, $.bob, $.alice);
        vm.stopPrank();
    }

    function test_int_proxy_withdrawWithTimelapByAssets(TestTypes.MarketPosition memory pos) public {
        vm.pauseGasMetering();
        pos = vm.generatePositionInLtvRange(pos, TestConstants.MIN_TEST_LLTV, $.marketConfig.lltv);

        $.oracle.setPrice(pos.price);
        $.loanToken.setBalance($.alice, pos.lent);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), pos.lent);
        marketProxy.deposit(pos.lent, $.bob);
        vm.stopPrank();

        vm.dahliaSupplyCollateralBy($.carol, pos.collateral, $);
        vm.dahliaBorrowBy($.carol, pos.borrowed, $);

        vm.forward(365 days); // 365 days

        vm.dahliaRepayBy($.carol, pos.borrowed, $);

        vm.startPrank($.bob);
        vm.resumeGasMetering();
        marketProxy.withdraw(pos.lent, $.alice, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq($.loanToken.balanceOf($.alice), pos.lent);
        assertEq(marketProxy.balanceOf($.alice), 0);
    }

    function test_int_proxy_withdrawWithApprove(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        uint256 shares = marketProxy.deposit(assets, $.alice);
        marketProxy.approve($.bob, shares);
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.resumeGasMetering();
        marketProxy.withdraw(assets, $.bob, $.alice);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq($.loanToken.balanceOf($.bob), assets);
        assertEq(marketProxy.balanceOf($.alice), 0);
        assertEq(marketProxy.balanceOf($.bob), 0);
    }

    bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function test_int_proxy_withdrawWithPermit(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);
        $.loanToken.setBalance($.alice, assets);

        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);
        uint256 shares = marketProxy.deposit(assets, $.alice);

        uint256 alicePrivateKey = uint256(bytes32(bytes("ALICE"))); // Logic from TestContext

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    WrappedVault(address(marketProxy)).DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, $.alice, $.bob, shares, 0, block.timestamp))
                )
            )
        );
        WrappedVault(address(marketProxy)).permit($.alice, $.bob, shares, block.timestamp, v, r, s);
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.resumeGasMetering();
        marketProxy.withdraw(assets, $.bob, $.alice);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq($.loanToken.balanceOf($.bob), assets);
        assertEq(marketProxy.balanceOf($.alice), 0);
        assertEq(marketProxy.balanceOf($.bob), 0);
    }

    function test_int_proxy_transferAndWithdraw(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);

        assertEq($.dahlia.getActualMarketState($.marketId).totalLendShares, 0, "totalLendShares initially 0");
        assertEq($.dahlia.getActualMarketState($.marketId).totalLendPrincipalAssets, 0, "totalLendPrincipalAssets initially 0");
        assertEq($.dahlia.getActualMarketState($.marketId).totalLendAssets, 0, "totalLendAssets initially 0");

        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq($.dahlia.getPosition($.marketId, $.bob).lendPrincipalAssets, assets, "bob has principal assets");
        assertEq($.dahlia.getPosition($.marketId, $.bob).lendShares, shares, "bob has principal shares");

        IDahlia.Market memory marketBeforeTransfer = $.dahlia.getActualMarketState($.marketId);

        vm.startPrank($.bob);
        vm.expectEmit(true, true, true, true, address(marketProxy));
        emit IWrappedVault.Transfer($.bob, $.carol, shares);
        vm.resumeGasMetering();
        marketProxy.transfer($.carol, shares);
        vm.pauseGasMetering();
        vm.stopPrank();

        IDahlia.Market memory marketAfterTransfer = $.dahlia.getActualMarketState($.marketId);

        assertEq(marketBeforeTransfer.totalLendShares, marketAfterTransfer.totalLendShares);
        assertEq(marketBeforeTransfer.totalLendPrincipalAssets, marketAfterTransfer.totalLendPrincipalAssets);
        assertEq(marketBeforeTransfer.totalLendAssets, marketAfterTransfer.totalLendAssets);
        assertEq(assets, marketAfterTransfer.totalLendAssets);
        assertEq(assets, marketAfterTransfer.totalLendPrincipalAssets);

        IDahlia.UserPosition memory carolPos = $.dahlia.getPosition($.marketId, $.carol);
        assertEq(shares, carolPos.lendShares, "carol lendShares=shares");
        assertEq(assets, carolPos.lendPrincipalAssets, "carol lendPrincipalAssets=assets");
        assertEq(shares, marketProxy.balanceOf($.carol));
        assertEq($.loanToken.balanceOf(address($.dahlia)), assets, "dahlia balance");

        IDahlia.UserPosition memory bobPos = $.dahlia.getPosition($.marketId, $.bob);
        assertEq(0, bobPos.lendShares, "bob lendShares=0");
        assertEq(0, bobPos.lendPrincipalAssets, "bob lendPrincipalAssets=0");
        assertEq(0, marketProxy.balanceOf($.bob));

        // deposit again from alice to bob
        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares2 = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.expectEmit(true, true, true, true, address(marketProxy));
        emit IWrappedVault.Transfer($.bob, $.carol, shares2);
        vm.resumeGasMetering();
        marketProxy.transfer($.carol, shares);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq(shares + shares2, $.dahlia.getPosition($.marketId, $.carol).lendShares, "carol lendShares=shares+shares2");
        assertEq(assets * 2, $.dahlia.getPosition($.marketId, $.carol).lendPrincipalAssets, "carol lendPrincipalAssets=assets*2");
        assertEq(shares + shares2, marketProxy.balanceOf($.carol), "marketProxy.balanceOf($.carol) lendShares=shares+shares2");
        assertEq(assets * 2, $.loanToken.balanceOf(address($.dahlia)), "dahlia balance=assets*2");

        vm.startPrank($.carol);
        vm.resumeGasMetering();
        vm.expectEmit(true, true, true, true, address($.dahlia));
        emit IDahlia.Withdraw($.marketId, address(marketProxy), $.alice, $.carol, assets * 2, shares + shares2);
        vm.expectEmit(true, true, true, true, address(marketProxy));
        emit IWrappedVault.Withdraw($.carol, $.alice, $.carol, assets * 2, shares + shares2);
        marketProxy.withdraw(assets * 2, $.alice, $.carol);
        vm.pauseGasMetering();
        vm.stopPrank();

        assertEq($.loanToken.balanceOf($.alice), assets * 2, "alice balance=assets*2");
        assertEq($.loanToken.balanceOf(address($.dahlia)), 0, "dahlia balance=0");
        assertEq($.dahlia.getActualMarketState($.marketId).totalLendShares, 0, "totalLendShares become 0");
        assertEq($.dahlia.getActualMarketState($.marketId).totalLendPrincipalAssets, 0, "totalLendPrincipalAssets become 0");
        assertEq($.dahlia.getActualMarketState($.marketId).totalLendAssets, 0, "totalLendAssets become 0");
    }

    function test_int_proxy_transferFrom_ERC20InsufficientAllowance(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);

        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.carol);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, $.carol, 0, shares));
        marketProxy.transferFrom($.bob, $.carol, shares);
        vm.pauseGasMetering();
        vm.stopPrank();
    }

    function test_int_proxy_transferFrom_ERC20InvalidApprover(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);

        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.carol);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, $.carol, 0, shares));
        marketProxy.transferFrom($.bob, $.carol, shares);
        vm.pauseGasMetering();
        vm.stopPrank();
    }

    function test_int_proxy_approve_ZeroAddress(uint256 assets) public {
        vm.pauseGasMetering();
        assets = vm.boundAmount(assets);

        $.loanToken.setBalance($.alice, assets);
        vm.startPrank($.alice);
        $.loanToken.approve(address(marketProxy), assets);

        vm.resumeGasMetering();
        uint256 shares = marketProxy.deposit(assets, $.bob);
        vm.pauseGasMetering();
        vm.stopPrank();

        vm.startPrank($.bob);
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        marketProxy.approve(address(0), shares);
        vm.pauseGasMetering();
        vm.stopPrank();
    }
}
