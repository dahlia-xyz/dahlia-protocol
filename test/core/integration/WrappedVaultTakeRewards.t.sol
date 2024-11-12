// SPDX-Liense-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test, Vm, console } from "@forge-std/Test.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";

import { ERC4626 } from "@solady/tokens/ERC4626.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { ERC20Mock as MockERC20 } from "test/common/mocks/ERC20Mock.sol";

library TestLib {
    uint8 public constant vaultERC20decimals = uint8(18);
    uint8 public constant vaultVirtualOffset = uint8(6);
    uint8 public constant rewardERC20decimals = uint8(6);
}

contract RewardMockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol, TestLib.rewardERC20decimals) { }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract VaultERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol, TestLib.vaultERC20decimals) { }

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
    using FixedPointMathLib for uint256;
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    MockERC20 token;
    WrappedVault testIncentivizedVault;

    PointsFactory pointsFactory = new PointsFactory(POINTS_FACTORY_OWNER);
    WrappedVaultFactory testFactory;
    uint256 constant WAD = 1e18;

    uint256 private constant DEFAULT_REFERRAL_FEE = 0.025e18;
    uint256 private constant DEFAULT_FRONTEND_FEE = 0.025e18;
    uint256 private constant DEFAULT_PROTOCOL_FEE = 0.05e18;

    address private constant DEFAULT_FEE_RECIPIENT = address(0x33f120);

    address public constant POINTS_FACTORY_OWNER = address(0x1);
    address public constant REFERRAL_USER = address(0x33f123);

    RewardMockERC20 rewardToken1;

    function setUp() public {
        ctx = new TestContext(vm);
        // change owner of vault to this test
        ctx.setWalletAddress("MARKET_DEPLOYER", address(this));
        // set default fee in dahliaRegistry
        Dahlia dahlia = ctx.createDahlia();
        testFactory = ctx.createRoycoWrappedVaultFactory(dahlia, address(this), DEFAULT_FEE_RECIPIENT, DEFAULT_PROTOCOL_FEE, DEFAULT_FRONTEND_FEE);

        vm.startPrank(ctx.createWallet("OWNER"));
        dahlia.dahliaRegistry().setValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_MIN_INITIAL_FRONTEND_FEE, DEFAULT_FRONTEND_FEE);
        vm.stopPrank();

        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv(), address(this));
        token = $.loanToken;

        testIncentivizedVault = WrappedVault(address(dahlia.getMarket($.marketId).vault));
        rewardToken1 = new RewardMockERC20("Reward Token 1", "RWD1");

        vm.label(address(testIncentivizedVault), "IncentivizedVault");
        vm.label(address(rewardToken1), "RewardToken1");
    }

    function testTakeRewards() public {
        // !!!!!! change this params for checking rewards
        uint256 rewardAmount = 100_000 * 10 ** TestLib.rewardERC20decimals; // 1000 USDC rewards
        uint256 depositAmount = 500 * 10 ** TestLib.vaultERC20decimals; // 500 ETH

        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;
        console.log("duration (seconds):", duration);

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);
        //assertEq(rewardToken1.balanceOf(address(testIncentivizedVault)), rewardAmount, "reward token on vault");

        RewardMockERC20(address(token)).mint($.alice, depositAmount);
        RewardMockERC20(address(token)).mint($.bob, depositAmount);

        vm.startPrank($.alice);
        token.approve(address(testIncentivizedVault), depositAmount);
        uint256 d1 = testIncentivizedVault.deposit(depositAmount, $.alice);
        vm.stopPrank();

        vm.startPrank($.bob);
        token.approve(address(testIncentivizedVault), depositAmount);
        uint256 d2 = testIncentivizedVault.deposit(depositAmount, $.bob);
        vm.stopPrank();

        console.log("user1 deposit:        ", d1);
        console.log("user2 deposit:        ", d2);
        console.log("undistributed rewards:", rewardToken1.balanceOf(address(testIncentivizedVault)));
        console.log("user1 rewards:        ", rewardToken1.balanceOf($.alice));
        console.log("user2 rewards:        ", rewardToken1.balanceOf($.bob));

        // 1000 USDC deposited by single user.
        vm.warp(start + duration / 2);
        vm.startPrank($.alice);
        testIncentivizedVault.claim($.alice);
        vm.stopPrank();
        vm.startPrank($.bob);
        testIncentivizedVault.claim($.bob);
        vm.stopPrank();
        vm.startPrank($.alice);
        testIncentivizedVault.withdraw(depositAmount, $.alice, $.alice);
        testIncentivizedVault.claim($.alice);
        vm.stopPrank();

        console.log("undistributed rewards:", rewardToken1.balanceOf(address(testIncentivizedVault)));
        console.log("user1 rewards:        ", rewardToken1.balanceOf($.alice));
        console.log("user2 rewards:        ", rewardToken1.balanceOf($.bob));

        vm.warp(start + duration + 1);
        vm.startPrank($.bob);
        testIncentivizedVault.claim($.bob);
        vm.stopPrank();
        console.log("\n #### End of rewards period. Expecting DEFAULT_FRONTEND_FEE and DEFAULT_PROTOCOL_FEE stay");
        console.log("User1: should take 1/4 and user2: should take 3/4");
        console.log("undistributed rewards:", rewardToken1.balanceOf(address(testIncentivizedVault)));
        console.log("user1 rewards:        ", rewardToken1.balanceOf($.alice));
        console.log("user2 rewards:        ", rewardToken1.balanceOf($.bob));
        vm.stopPrank();
    }
}
