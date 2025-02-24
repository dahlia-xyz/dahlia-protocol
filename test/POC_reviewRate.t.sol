// SPDX-Liense-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test, Vm, console } from "@forge-std/Test.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { ERC4626 } from "@solady/tokens/ERC4626.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { LibString } from "@solmate/utils/LibString.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";

import { DahliaTransUtils } from "test/common/DahliaTransUtils.sol";
import { TestContext } from "test/common/TestContext.sol";

library TestLib {
    uint8 public constant vaultERC20decimals = uint8(6);
    uint8 public constant vaultVirtualOffset = uint8(0);
    uint8 public constant rewardERC20decimals1 = uint8(6);
    uint8 public constant rewardERC20decimals2 = uint8(18);
}

contract RewardMockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) { }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract VaultERC4626 is ERC4626 {
    address internal immutable _underlying;

    constructor(ERC20 _asset) {
        _underlying = address(_asset);
    }

    function asset() public view virtual override returns (address) {
        return _underlying;
    }

    function name() public view virtual override returns (string memory) {
        return "Base Vault";
    }

    function symbol() public view virtual override returns (string memory) {
        return "bVault";
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return TestLib.vaultVirtualOffset;
    }

    function _useVirtualShares() internal view virtual override returns (bool) {
        return true;
    }

    function _underlyingDecimals() internal view virtual override returns (uint8) {
        return TestLib.vaultERC20decimals;
    }
}

contract WrappedVaultTakeRewardsTest is Test {
    using FixedPointMathLib for *;
    using LibString for *;
    using DahliaTransUtils for Vm;

    WrappedVault testIncentivizedVault;

    PointsFactory pointsFactory = new PointsFactory(POINTS_FACTORY_OWNER);
    WrappedVaultFactory testFactory;
    uint256 constant WAD = 1e18;

    uint256 constant DEFAULT_REFERRAL_FEE = 0.025e18;
    uint256 constant DEFAULT_FRONTEND_FEE = 0.025e18;
    uint256 constant DEFAULT_PROTOCOL_FEE = 0.05e18;

    address constant DEFAULT_FEE_RECIPIENT = address(0x33f120);

    address public constant POINTS_FACTORY_OWNER = address(0x1);
    address public constant REGULAR_USER = address(0x33f121);
    uint256 public depositAmount; // 50 WETH

    RewardMockERC20 usdcToken;
    RewardMockERC20 ghoToken;

    TestContext.MarketContext $;
    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
        $ = ctx.bootstrapMarket("USDC", "WBTC", BoundUtils.toPercent(80));
        testIncentivizedVault = $.vault;
        depositAmount = 10_000 * 10 ** $.loanToken.decimals();
        usdcToken = new RewardMockERC20("Reward USDC", "USDC", TestLib.rewardERC20decimals1);
        ghoToken = new RewardMockERC20("Reward GHO", "GHO", TestLib.rewardERC20decimals2);

        vm.label(address(testIncentivizedVault), "IncentivizedVault");
        vm.label(address(usdcToken), "USDC");
        vm.label(address(ghoToken), "GHO");
        vm.label(REGULAR_USER, "RegularUser");
    }

    function getRate(string memory suffix, RewardMockERC20 erc20) public view {
        (,, uint256 rate) = testIncentivizedVault.rewardToInterval(address(erc20));
        console.log(
            string(abi.encodePacked(suffix, " ", erc20.name(), " vault.rewardToInterval.rate=", rate.toString(), " decimals=", erc20.decimals().toString()))
        );
        console.log(suffix, erc20.name(), "vault.previewRateAfterDeposit=", testIncentivizedVault.previewRateAfterDeposit(address(erc20), depositAmount));
    }

    function printUserPos(string memory suffix) public view {
        getRate(suffix, usdcToken);
        getRate(suffix, ghoToken);
        console.log("");
    }

    function testPreviewRate() public {
        // !!!!!! change this params for checking rewards
        uint256 rewardAmount1 = 10_000 * 10 ** TestLib.rewardERC20decimals1; // 10_000 USDC
        uint256 rewardAmount2 = 10_000 * 10 ** TestLib.rewardERC20decimals2; // 10_000 GHO

        uint32 start = uint32(block.timestamp);
        uint32 duration = 365.24 days;
        console.log("Campaign Duration: 30 days");
        console.log(string(abi.encodePacked("Lending: ", $.loanToken.symbol(), " decimals=", $.loanToken.decimals().toString())));
        console.log("USDC Rewards: ", rewardAmount1 / 10 ** TestLib.rewardERC20decimals1);
        console.log("GHO Rewards: ", rewardAmount2 / 10 ** TestLib.rewardERC20decimals2);
        console.log("User Initial Deposit: ", depositAmount / 10 ** TestLib.vaultERC20decimals);
        console.log("frontendFee: ", $.vault.frontendFee());
        console.log("protocolFee:", $.vault.WRAPPED_VAULT_FACTORY().protocolFee());
        printUserPos("0");
        console.log("");

        vm.prank($.vault.owner());
        testIncentivizedVault.addRewardsToken(address(usdcToken));
        vm.prank($.vault.owner());
        testIncentivizedVault.addRewardsToken(address(ghoToken));

        // Set reward interval for USDC for 30 days
        vm.startPrank($.marketAdmin);
        usdcToken.mint($.marketAdmin, rewardAmount1);
        usdcToken.approve(address(testIncentivizedVault), rewardAmount1);
        vm.stopPrank();
        vm.prank($.vault.owner());
        testIncentivizedVault.setRewardsInterval(address(usdcToken), start, start + duration, rewardAmount1, DEFAULT_FEE_RECIPIENT);
        // Set reward interval for DAHLIA for 30 days
        vm.startPrank($.marketAdmin);
        ghoToken.mint($.marketAdmin, rewardAmount2);
        ghoToken.approve(address(testIncentivizedVault), rewardAmount2);
        vm.stopPrank();
        vm.prank($.vault.owner());
        testIncentivizedVault.setRewardsInterval(address(ghoToken), start, start + duration, rewardAmount2, DEFAULT_FEE_RECIPIENT);
        printUserPos("1 after setRewardsInterval");

        // Deposit `depositAmount` into the vault
        vm.dahliaLendBy(REGULAR_USER, depositAmount, $);

        //
        printUserPos(string(abi.encodePacked("2 after lending of ", (depositAmount / 10 ** $.loanToken.decimals()).toString(), " ", $.loanToken.symbol())));
    }
}
