// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test, Vm } from "@forge-std/Test.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

contract WrappedVaultRateAfterDepositTest is Test {
    using LibString for uint256;
    using FixedPointMathLib for uint256;
    using DahliaTransUtils for Vm;
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext.MarketContext $$;
    TestContext ctx;

    PointsFactory pointsFactory = new PointsFactory(POINTS_FACTORY_OWNER);
    WrappedVaultFactory testFactory;
    uint256 constant WAD = 1e18;

    uint256 private constant DEFAULT_REFERRAL_FEE = 0.0e18;
    uint256 private constant DEFAULT_FRONTEND_FEE = 0.0e18;
    uint256 private constant DEFAULT_PROTOCOL_FEE = 0.0e18;

    address private constant DEFAULT_FEE_RECIPIENT = address(0x33f120);

    address public constant POINTS_FACTORY_OWNER = address(0x1);

    uint256 private SECONDS_IN_YEAR = 31_536_000;

    function setUp() public {
        ctx = new TestContext(vm);
        // change owner of vault to this test
        ctx.setWalletAddress("MARKET_DEPLOYER", address(this));
        // set default fee in dahliaRegistry
        Dahlia dahlia = ctx.createDahlia();
        testFactory = ctx.createRoycoWrappedVaultFactory(dahlia, address(this), DEFAULT_FEE_RECIPIENT, DEFAULT_PROTOCOL_FEE, DEFAULT_FRONTEND_FEE);

        vm.startPrank(ctx.createWallet("OWNER"));
        dahlia.dahliaRegistry().setValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_INITIAL_FRONTEND_FEE, DEFAULT_FRONTEND_FEE);
        vm.stopPrank();

        $ = ctx.bootstrapMarket("USDC", "WETH", vm.randomLltv(), address(this));
    }

    function test_wrappedVault_previewRateAfterDeposit() public {
        uint256 depositAmount = 100_000 * 10 ** $.loanToken.decimals();
        uint256 collateralAmount = 1_000_000 * 10 ** $.collateralToken.decimals();
        uint256 borrowAmount = 99_000 * 10 ** $.loanToken.decimals();
        uint256 potentialDepositAssets = 1000 * 10 ** $.loanToken.decimals();

        uint256 price = 1e36; // 1 to 1
        $.oracle.setPrice(price);
        vm.dahliaLendBy($.carol, depositAmount, $);
        vm.dahliaSupplyCollateralBy($.alice, collateralAmount, $);
        vm.dahliaBorrowBy($.alice, borrowAmount, $);

        vm.forward(1);
        uint256 dahliaRatePerSec = $.dahlia.previewLendRateAfterDeposit($.marketId, potentialDepositAssets);
        assertEq(dahliaRatePerSec, 1_403_640_141, "rate per sec");
        assertEq(dahliaRatePerSec * SECONDS_IN_YEAR, 44_265_195_486_576_000, "rate per year"); // 4.42% yearly

        uint256 ratePerSec = $.vault.previewRateAfterDeposit(address($.loanToken), potentialDepositAssets);
        uint256 profitYearly = ratePerSec * SECONDS_IN_YEAR * potentialDepositAssets / 1e18;

        assertEq(ratePerSec, 1_403_640_143, "rate per second after deposit");
        assertEq(profitYearly, 44_265_195, "profit yearly"); // 44.02 tokens from 1000
    }
}
