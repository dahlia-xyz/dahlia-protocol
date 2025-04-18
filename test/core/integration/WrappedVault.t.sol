// SPDX-Liense-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { Ownable as SoladyOwnable } from "@solady/auth/Ownable.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { InitializableERC20 } from "src/royco/periphery/InitializableERC20.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { ERC20Mock as MockERC20 } from "test/common/mocks/ERC20Mock.sol";

contract MockERC4626 is ERC4626 {
    constructor(ERC20 _asset) ERC4626(_asset, "Base Vault", "bVault") { }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

contract WrappedVaultTest is Test {
    using FixedPointMathLib for *;
    using BoundUtils for Vm;

    TestContext.MarketContext $;
    TestContext ctx;

    WrappedVault testIncentivizedVault;
    PointsFactory pointsFactory;
    WrappedVaultFactory testFactory;
    MockERC20 token;

    uint256 constant WAD = 1e18;

    uint256 constant DEFAULT_REFERRAL_FEE = 0.025e18;
    uint256 constant DEFAULT_FRONTEND_FEE = 0.025e18;
    uint256 constant DEFAULT_PROTOCOL_FEE = 0.05e18;

    address constant DEFAULT_FEE_RECIPIENT = address(0xdead);

    address public constant REGULAR_USER = address(0xbeef);
    address public constant REFERRAL_USER = address(0x33f123);

    MockERC20 rewardToken1;
    MockERC20 rewardToken2;

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

        $ = ctx.bootstrapMarket("USDC", "WBTC", vm.randomLltv(), address(this));
        token = $.loanToken;

        testIncentivizedVault = WrappedVault(address(dahlia.getMarket($.marketId).vault));
        pointsFactory = testIncentivizedVault.POINTS_FACTORY();
        rewardToken1 = ctx.createERC20Token("RewardToken1", 8);
        rewardToken2 = ctx.createERC20Token("RewardToken2", 10);

        vm.label(address(testIncentivizedVault), "IncentivizedVault");
        vm.label(REGULAR_USER, "RegularUser");
        vm.label(REFERRAL_USER, "ReferralUser");
    }

    function testFactoryUpdateProtocolFees() public {
        vm.startPrank(address(0x8482));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x8482)));
        testFactory.updateProtocolFee(0.01e18);
        vm.stopPrank();

        vm.startPrank(testFactory.owner());
        uint256 maxProtocolFee = testFactory.MAX_PROTOCOL_FEE();
        vm.expectRevert(WrappedVaultFactory.ProtocolFeeTooHigh.selector);
        testFactory.updateProtocolFee(maxProtocolFee + 1);

        testFactory.updateProtocolFee(0.075e18);
        assertEq(testFactory.protocolFee(), 0.075e18);
    }

    function testFactoryUpdateReferralFee() public {
        vm.startPrank(address(0x8482));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x8482)));
        testFactory.updateMinimumReferralFee(0.01e18);
        vm.stopPrank();

        vm.startPrank(testFactory.owner());
        uint256 maxMinFee = testFactory.MAX_MIN_REFERRAL_FEE();
        vm.expectRevert(WrappedVaultFactory.ReferralFeeTooHigh.selector);
        testFactory.updateMinimumReferralFee(maxMinFee + 1);

        testFactory.updateMinimumReferralFee(0.075e18);
        assertEq(testFactory.minimumFrontendFee(), 0.075e18);
    }

    function testDeployment() public view {
        assertEq(address(testIncentivizedVault.asset()), address(token));
        assertEq(testIncentivizedVault.owner(), address(this));
        assertEq(testIncentivizedVault.frontendFee(), DEFAULT_FRONTEND_FEE);
    }

    function testAddRewardToken(address newRewardToken) public {
        vm.assume(newRewardToken != address(0));
        vm.assume(newRewardToken != address(testIncentivizedVault));

        testIncentivizedVault.addRewardsToken(newRewardToken);
        assertEq(testIncentivizedVault.rewards(0), newRewardToken);

        // Test we cannot add the second reward token twice
        vm.expectRevert(WrappedVault.DuplicateRewardToken.selector);
        testIncentivizedVault.addRewardsToken(newRewardToken);
    }

    function testAddRewardTokenUnauthorized(address unauthorized) public {
        vm.assume(unauthorized != address(this));
        vm.expectRevert(abi.encodeWithSelector(SoladyOwnable.Unauthorized.selector));
        vm.prank(unauthorized);
        testIncentivizedVault.addRewardsToken(address(rewardToken1));
    }

    function testAddRewardTokenMaxReached() public {
        for (uint256 i = 0; i < testIncentivizedVault.MAX_REWARDS(); i++) {
            testIncentivizedVault.addRewardsToken(address(new MockERC20("", "", 6)));
        }

        address mockToken = address(new MockERC20("", "", 6));
        vm.expectRevert(WrappedVault.MaxRewardsReached.selector);
        testIncentivizedVault.addRewardsToken(mockToken);
    }

    function testSetFrontendFee(uint256 newFee) public {
        vm.assume(newFee >= testFactory.minimumFrontendFee() && newFee <= WAD);
        testIncentivizedVault.setFrontendFee(newFee);
        assertEq(testIncentivizedVault.frontendFee(), newFee);
    }

    function testSetFrontendFeeBelowMinimum(uint256 newFee) public {
        vm.assume(newFee < testFactory.minimumFrontendFee());
        vm.expectRevert(WrappedVault.FrontendFeeBelowMinimum.selector);
        testIncentivizedVault.setFrontendFee(newFee);
    }

    function testSetRewardsInterval(uint32 start, uint32 duration, uint256 totalRewards) public {
        vm.assume(start != 0);
        vm.assume(duration >= testIncentivizedVault.MIN_CAMPAIGN_DURATION());
        vm.assume(duration <= type(uint32).max - start); //If this is not here, then 'end' variable will overflow
        vm.assume(totalRewards > 0 && totalRewards < type(uint96).max);
        vm.assume(totalRewards / duration > 1e6);

        uint32 end = start + duration;
        testIncentivizedVault.addRewardsToken(address(rewardToken1));

        rewardToken1.mint(address(this), totalRewards);
        rewardToken1.approve(address(testIncentivizedVault), totalRewards);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, end, totalRewards, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = totalRewards.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = totalRewards.mulWadDown(testFactory.protocolFee());
        totalRewards -= frontendFee + protocolFee;

        (uint32 actualStart, uint32 actualEnd, uint96 actualRate) = testIncentivizedVault.rewardToInterval(address(rewardToken1));

        assertEq(actualStart, start);
        assertEq(actualEnd, end);
        assertEq(actualRate, totalRewards / duration);
    }

    function testExtendRewardsInterval(uint256 start, uint256 initialDuration, uint256 extension, uint256 initialRewards, uint256 additionalRewards) public {
        // Bound start to uint32 range
        start = bound(start, 1, type(uint32).max);

        // Calculate the remaining space in uint32 after accounting for start
        uint256 remainingSpace = type(uint32).max - start;

        // Get the minimum campaign duration
        uint256 minCampaignDuration = testIncentivizedVault.MIN_CAMPAIGN_DURATION();

        // Ensure there is enough remaining space for the initial duration
        if (remainingSpace < minCampaignDuration) {
            return;
        }

        // Bound initialDuration between minCampaignDuration and remainingSpace
        initialDuration = bound(initialDuration, minCampaignDuration, remainingSpace);

        // Calculate initialEnd and ensure it doesn't overflow
        uint256 initialEnd = start + initialDuration;

        // Calculate the remaining space after initialEnd
        uint256 remainingSpaceAfterInitialEnd = type(uint32).max - initialEnd;

        // Ensure there is enough remaining space for the extension
        if (remainingSpaceAfterInitialEnd < 1 days + 1) {
            return;
        }

        // Bound extension between 1 day + 1 and the remaining space after initialEnd
        extension = bound(extension, 1 days + 1, remainingSpaceAfterInitialEnd);

        // Calculate newEnd and ensure it doesn't overflow
        uint256 newEnd = initialEnd + extension;

        // Ensure that start, initialEnd, and newEnd fit within uint32
        if (start > type(uint32).max || initialEnd > type(uint32).max || newEnd > type(uint32).max) {
            return;
        }

        // Cast to uint32 after ensuring values are within uint32 range
        uint32 _start = uint32(start);
        uint32 _initialEnd = uint32(initialEnd);
        uint32 _newEnd = uint32(newEnd);

        // Ensure initialRewards is within specified bounds and satisfies the rate condition
        uint256 minInitialRewards = (initialDuration * 1e6) + 1;
        uint256 maxInitialRewards = type(uint96).max - 1;

        if (maxInitialRewards < minInitialRewards) {
            return; // Cannot proceed if maxInitialRewards is less than minInitialRewards
        }

        initialRewards = bound(initialRewards, minInitialRewards, maxInitialRewards);

        // Ensure additionalRewards is within specified bounds
        uint256 minAdditionalRewards = 1e6 + 1;
        uint256 maxAdditionalRewards = type(uint96).max - 1;

        if (maxAdditionalRewards < minAdditionalRewards) {
            return; // Cannot proceed if maxAdditionalRewards is less than minAdditionalRewards
        }

        additionalRewards = bound(additionalRewards, minAdditionalRewards, maxAdditionalRewards);

        // Ensure initialRewards / initialDuration > 1e6
        if (initialRewards / initialDuration <= 1e6) {
            // Adjust initialRewards to satisfy the condition
            initialRewards = (initialDuration * 1e6) + 1e18;
        }

        // Adjust additionalRewards if the rate condition is not met
        if (additionalRewards / extension <= initialRewards / initialDuration) {
            additionalRewards = ((initialRewards / initialDuration) * extension) + 1e18;
        }

        testIncentivizedVault.addRewardsToken(address(rewardToken1));

        rewardToken1.mint(address(this), initialRewards + additionalRewards);
        rewardToken1.approve(address(testIncentivizedVault), initialRewards + additionalRewards);

        testIncentivizedVault.setRewardsInterval(address(rewardToken1), _start, _initialEnd, initialRewards, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = initialRewards.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = initialRewards.mulWadDown(testFactory.protocolFee());
        initialRewards -= frontendFee + protocolFee;

        vm.warp(start + (initialDuration / 2)); // Warp to middle of interval

        // Ensure the new campaign duration meets the minimum requirement
        if (newEnd - block.timestamp < minCampaignDuration) {
            return;
        }

        testIncentivizedVault.extendRewardsInterval(address(rewardToken1), additionalRewards, _newEnd, address(this));

        frontendFee = additionalRewards.mulWadDown(testIncentivizedVault.frontendFee());
        protocolFee = additionalRewards.mulWadDown(testFactory.protocolFee());
        additionalRewards -= frontendFee + protocolFee;

        (uint32 actualStart, uint32 actualEnd, uint96 actualRate) = testIncentivizedVault.rewardToInterval(address(rewardToken1));
        assertEq(actualStart, block.timestamp);
        assertEq(actualEnd, _newEnd);

        uint256 remainingInitialRewards = (initialRewards / initialDuration) * (_initialEnd - block.timestamp);
        uint256 expectedRate = (remainingInitialRewards + additionalRewards) / (_newEnd - block.timestamp);
        assertEq(actualRate, expectedRate);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);
        MockERC20(address(token)).mint(REGULAR_USER, amount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), amount);
        uint256 shares = testIncentivizedVault.deposit(amount, REGULAR_USER);
        vm.stopPrank();

        assertEq(testIncentivizedVault.balanceOf(REGULAR_USER), shares);
        assertEq(testIncentivizedVault.totalAssets(), amount);
    }

    function testRefundInterval(uint32 start, uint32 duration, uint256 totalRewards) public {
        if (start < block.timestamp + 10_000) {
            start = uint32(block.timestamp + 10_000);
        }

        vm.assume(duration >= testIncentivizedVault.MIN_CAMPAIGN_DURATION());
        vm.assume(duration <= type(uint32).max - start); //If this is not here, then 'end' variable will overflow
        vm.assume(totalRewards > 0 && totalRewards < type(uint96).max);
        vm.assume(totalRewards / duration > 1e6);

        uint32 end = start + duration;
        testIncentivizedVault.addRewardsToken(address(rewardToken1));

        rewardToken1.mint(address(this), totalRewards);
        rewardToken1.approve(address(testIncentivizedVault), totalRewards);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, end, totalRewards, DEFAULT_FEE_RECIPIENT);

        vm.startPrank(REGULAR_USER);
        vm.expectRevert(SoladyOwnable.Unauthorized.selector);
        testIncentivizedVault.refundRewardsInterval(address(rewardToken1));
        vm.stopPrank();

        uint256 initialBalance = rewardToken1.balanceOf(address(this));
        assertGt(initialBalance, 0);
        testIncentivizedVault.refundRewardsInterval(address(rewardToken1));
    }

    function testWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= type(uint96).max);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);

        testIncentivizedVault.withdraw(withdrawAmount, REGULAR_USER, REGULAR_USER);
        vm.stopPrank();

        assertEq(token.balanceOf(REGULAR_USER), withdrawAmount);
        assertEq(testIncentivizedVault.totalAssets(), depositAmount - withdrawAmount);
    }

    function testRewardsAccrual(uint32 start, uint256 depositAmount, uint32 timeElapsed) public {
        vm.assume(depositAmount > 1e6 && depositAmount <= type(uint96).max);
        vm.assume(timeElapsed > 7 days && timeElapsed <= 30 days);

        uint256 rewardAmount = 1000 * WAD;
        start = uint32(bound(start, 1, block.timestamp));
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = rewardAmount.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = rewardAmount.mulWadDown(testFactory.protocolFee());
        rewardAmount -= frontendFee + protocolFee;

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        uint256 shares = testIncentivizedVault.principal(REGULAR_USER);
        assertEq(depositAmount, shares, "principal should belong to user");
        vm.stopPrank();

        vm.warp(start + timeElapsed);

        uint256 expectedRewards = (rewardAmount * timeElapsed) * shares / testIncentivizedVault.totalPrincipal() / duration;
        uint256 actualRewards = testIncentivizedVault.currentUserRewards(address(rewardToken1), REGULAR_USER);

        assertApproxEqRel(actualRewards, expectedRewards, 1e15); // Allow 0.1% deviation
    }

    function testClaim(uint96 _depositAmount, uint32 timeElapsed) public {
        uint256 depositAmount = _depositAmount;

        vm.assume(depositAmount > 1e6);
        vm.assume(depositAmount <= type(uint96).max);
        vm.assume(timeElapsed > 1e6);
        vm.assume(timeElapsed <= 30 days);

        uint256 rewardAmount = 1000 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = rewardAmount.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = rewardAmount.mulWadDown(testFactory.protocolFee());

        rewardAmount -= frontendFee + protocolFee;

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        uint256 shares = testIncentivizedVault.principal(REGULAR_USER);
        vm.warp(timeElapsed);

        uint256 expectedRewards = (rewardAmount / duration) * shares / testIncentivizedVault.totalPrincipal() * timeElapsed;
        testIncentivizedVault.rewardToInterval(address(rewardToken1));

        testIncentivizedVault.claim(REGULAR_USER);
        vm.stopPrank();

        assertApproxEqRel(rewardToken1.balanceOf(REGULAR_USER), expectedRewards, 2e15); // Allow 0.2% deviation
    }

    function testMultipleRewardTokens(uint256 depositAmount, uint32 timeElapsed) public {
        vm.assume(depositAmount > 1e6 && depositAmount <= type(uint96).max);
        vm.assume(timeElapsed > 1e6 && timeElapsed <= 30 days);

        uint256 rewardAmount1 = 1000 * WAD;
        uint256 rewardAmount2 = 500 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        testIncentivizedVault.addRewardsToken(address(rewardToken2));

        rewardToken1.mint(address(this), rewardAmount1);
        rewardToken2.mint(address(this), rewardAmount2);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount1);
        rewardToken2.approve(address(testIncentivizedVault), rewardAmount2);

        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount1, DEFAULT_FEE_RECIPIENT);
        testIncentivizedVault.setRewardsInterval(address(rewardToken2), start, start + duration, rewardAmount2, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = rewardAmount1.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = rewardAmount1.mulWadDown(testFactory.protocolFee());
        rewardAmount1 -= frontendFee + protocolFee;

        frontendFee = rewardAmount2.mulWadDown(testIncentivizedVault.frontendFee());
        protocolFee = rewardAmount2.mulWadDown(testFactory.protocolFee());
        rewardAmount2 -= frontendFee + protocolFee;

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        uint256 shares = testIncentivizedVault.principal(REGULAR_USER);
        vm.warp(start + timeElapsed);

        testIncentivizedVault.claim(REGULAR_USER);
        vm.stopPrank();

        uint256 expectedRewards1 = (rewardAmount1 / duration) * shares / testIncentivizedVault.totalPrincipal() * timeElapsed;
        uint256 expectedRewards2 = (rewardAmount2 / duration) * shares / testIncentivizedVault.totalPrincipal() * timeElapsed;

        assertApproxEqRel(rewardToken1.balanceOf(REGULAR_USER), expectedRewards1, 1e15);
        assertApproxEqRel(rewardToken2.balanceOf(REGULAR_USER), expectedRewards2, 1e15);
    }

    function testRewardsAfterWithdraw(uint256 depositAmount, uint32 timeElapsed, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 1e6 && depositAmount <= type(uint96).max);
        vm.assume(timeElapsed > 0 && timeElapsed < 30 days);
        vm.assume(withdrawAmount > 0 && withdrawAmount < depositAmount);

        uint256 rewardAmount = 1000 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = rewardAmount.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = rewardAmount.mulWadDown(testFactory.protocolFee());
        rewardAmount -= frontendFee + protocolFee;

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        uint256 shares = testIncentivizedVault.principal(REGULAR_USER);
        vm.warp(start + timeElapsed);

        uint256 supply = testIncentivizedVault.totalPrincipal();

        testIncentivizedVault.withdraw(withdrawAmount, REGULAR_USER, REGULAR_USER);
        vm.stopPrank();

        uint256 expectedRewards = rewardAmount * timeElapsed / duration * shares / supply;
        assertApproxEqRel(testIncentivizedVault.currentUserRewards(address(rewardToken1), REGULAR_USER), expectedRewards, 5e15);
    }

    function testFeeClaiming(uint256 depositAmount, uint32 timeElapsed) public {
        vm.assume(depositAmount > 0 && depositAmount <= type(uint96).max);
        vm.assume(timeElapsed > 0 && timeElapsed <= 30 days);

        uint256 rewardAmount = 1000 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        address FRONTEND_FEE_RECIPIENT = address(0x08989);

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, FRONTEND_FEE_RECIPIENT);

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        vm.warp(start + timeElapsed);
        vm.stopPrank();

        uint256 expectedFrontendFee = (rewardAmount * DEFAULT_FRONTEND_FEE) / WAD;
        uint256 expectedProtocolFee = (rewardAmount * DEFAULT_PROTOCOL_FEE) / WAD;

        vm.prank(FRONTEND_FEE_RECIPIENT);
        testIncentivizedVault.claimFees(FRONTEND_FEE_RECIPIENT);
        assertApproxEqRel(rewardToken1.balanceOf(FRONTEND_FEE_RECIPIENT), expectedFrontendFee, 1e15);

        vm.prank(DEFAULT_FEE_RECIPIENT);
        testIncentivizedVault.claimFees(DEFAULT_FEE_RECIPIENT);
        assertApproxEqRel(rewardToken1.balanceOf(DEFAULT_FEE_RECIPIENT), expectedProtocolFee, 1e15);
    }

    function testRewardsRateAfterDeposit() public {
        uint256 initialDeposit = 100e18;
        uint256 additionalDeposit = initialDeposit * 2;

        uint256 rewardAmount = 1000 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        MockERC20(address(token)).mint(REGULAR_USER, initialDeposit + additionalDeposit);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), initialDeposit + additionalDeposit);
        testIncentivizedVault.deposit(initialDeposit, REGULAR_USER);

        uint256 initialRate = testIncentivizedVault.previewRateAfterDeposit(address(rewardToken1), 1e18);
        testIncentivizedVault.deposit(additionalDeposit, REGULAR_USER);
        uint256 finalRate = testIncentivizedVault.previewRateAfterDeposit(address(rewardToken1), 1e18);

        vm.stopPrank();

        assertLt(finalRate, initialRate, "Rate should decrease after additional deposit");
    }

    function testExtremeValues(uint256 depositAmount) public {
        vm.assume(depositAmount > 1e18 && depositAmount <= type(uint96).max);

        uint256 rewardAmount = type(uint96).max;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 365 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        vm.warp(start + duration);

        uint256 rewards = testIncentivizedVault.currentUserRewards(address(rewardToken1), REGULAR_USER);
        assertLe(rewards, rewardAmount, "Rewards should not exceed total reward amount");

        testIncentivizedVault.claim(REGULAR_USER);
        vm.stopPrank();

        assertEq(rewardToken1.balanceOf(REGULAR_USER), rewards, "User should receive all accrued rewards");
    }

    function testRewardsAccrualWithMultipleUsers(uint256[] memory deposits, uint32 timeElapsed) public {
        vm.assume(deposits.length > 1 && deposits.length <= 10);
        vm.assume(timeElapsed > 0 && timeElapsed <= 30 days);

        uint256 totalDeposit;
        for (uint256 i = 0; i < deposits.length; i++) {
            deposits[i] = bound(deposits[i], 1e7, type(uint96).max / deposits.length);
            totalDeposit += deposits[i];
        }

        uint256 rewardAmount = 1000 * WAD;
        uint32 start = uint32(block.timestamp);
        uint32 duration = 30 days;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), rewardAmount);
        rewardToken1.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        uint256 frontendFee = rewardAmount.mulWadDown(testIncentivizedVault.frontendFee());
        uint256 protocolFee = rewardAmount.mulWadDown(testFactory.protocolFee());
        rewardAmount -= frontendFee + protocolFee;

        uint256[] memory shares = new uint256[](deposits.length);

        for (uint256 i = 0; i < deposits.length; i++) {
            address user = address(uint160(i + 1));
            MockERC20(address(token)).mint(user, deposits[i]);
            vm.startPrank(user);
            token.approve(address(testIncentivizedVault), deposits[i]);
            uint256 share = testIncentivizedVault.deposit(deposits[i], user);
            shares[i] = share;
            vm.stopPrank();
        }

        vm.warp(start + timeElapsed);

        uint256 totalRewards;
        uint256 totalShares;
        for (uint256 i = 0; i < deposits.length; i++) {
            address user = address(uint160(i + 1));
            uint256 userRewards = testIncentivizedVault.currentUserRewards(address(rewardToken1), user);
            totalRewards += userRewards;
            totalShares += shares[i];

            uint256 expectedRewards = rewardAmount * timeElapsed / duration * shares[i] / testIncentivizedVault.totalSupply();
            assertApproxEqRel(userRewards, expectedRewards, 0.005e18, "Incorrect rewards for user");
        }

        assertApproxEqRel(
            totalRewards, (rewardAmount * timeElapsed) * totalShares / testIncentivizedVault.totalSupply() / duration, 1e15, "Total rewards mismatch"
        );
    }

    function testStartZeroExtendRewardsInterval() public {
        uint32 initialTime = 1000 days; // nice round number
        vm.warp(initialTime); // just get off of zero for realism

        uint32 start = 1;
        uint32 initialEnd = initialTime + 10 days;
        uint32 newEnd = initialEnd + 10 days;

        uint256 initialRewards = 10e18;
        uint256 additionalRewards = 10e18;

        testIncentivizedVault.addRewardsToken(address(rewardToken1));
        rewardToken1.mint(address(this), initialRewards + additionalRewards);
        rewardToken1.approve(address(testIncentivizedVault), initialRewards + additionalRewards);
        testIncentivizedVault.setRewardsInterval(address(rewardToken1), start, initialEnd, initialRewards, DEFAULT_FEE_RECIPIENT);

        // user deposits
        MockERC20(address(token)).mint(REGULAR_USER, 1e18);
        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), type(uint256).max);
        testIncentivizedVault.deposit(1e18, REGULAR_USER);
        vm.stopPrank();

        vm.warp(initialTime + (initialEnd - initialTime) / 2); // let some time elapse, but interval isn't over yet

        testIncentivizedVault.extendRewardsInterval(address(rewardToken1), additionalRewards, newEnd, address(this));

        // user deposits even more--this will their rewards to be updated
        MockERC20(address(token)).mint(REGULAR_USER, 1e18);
        vm.startPrank(REGULAR_USER);
        testIncentivizedVault.deposit(1e18, REGULAR_USER);
        vm.stopPrank();

        assertLt(testIncentivizedVault.currentUserRewards(address(rewardToken1), REGULAR_USER), rewardToken1.balanceOf(address(testIncentivizedVault)));
    }

    /// See https://cantina.xyz/code/691ce303-f137-437a-bf34-aef87dfe983b/findings?finding=19
    function testSelfTransfer(uint256 depositAmount) public {
        emit log_named_uint("Max totalPrincipal", $.vault.maxDeposit(REGULAR_USER));
        vm.assume(depositAmount <= $.vault.maxDeposit(REGULAR_USER));
        assertEq(testIncentivizedVault.totalPrincipal(), Constants.BURN_ASSET, "initial total principal should be 1");
        MockERC20(address(token)).mint(REGULAR_USER, depositAmount);

        vm.startPrank(REGULAR_USER);
        token.approve(address(testIncentivizedVault), depositAmount);
        uint256 depositedShares = testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        vm.stopPrank();

        assertEq(testIncentivizedVault.totalPrincipal(), depositAmount + Constants.BURN_ASSET, "after deposit");
        assertEq(testIncentivizedVault.principal(REGULAR_USER), depositAmount);

        uint256 shares = testIncentivizedVault.balanceOf(REGULAR_USER);

        vm.expectEmit(true, true, true, true, address($.vault));
        emit InitializableERC20.Transfer(REGULAR_USER, REGULAR_USER, shares);

        //@audit self transfer
        vm.startPrank(REGULAR_USER);
        testIncentivizedVault.transfer(REGULAR_USER, shares);
        vm.stopPrank();

        emit log_named_uint("Actual totalPrincipal", testIncentivizedVault.totalPrincipal());
        emit log_named_uint("Actual principal", testIncentivizedVault.principal(REGULAR_USER));

        assertEq(testIncentivizedVault.totalPrincipal() - Constants.BURN_ASSET, depositAmount, "total principal should not change");
        assertEq(testIncentivizedVault.principal(REGULAR_USER), depositAmount, "principal of user should be the same");
        assertEq(testIncentivizedVault.balanceOf(REGULAR_USER), depositedShares, "deposited shares should be the same");
    }

    function testRewardRateForDepositAsset() public {
        uint256 depositAmount = 10 * 1e18;
        uint256 rewardAmount = 1000 * WAD;

        vm.warp(100_000_000);

        uint32 start = uint32(block.timestamp);
        uint256 activeRewardPeriod = 9 weeks;
        uint256 duration = activeRewardPeriod + testIncentivizedVault.MIN_CAMPAIGN_DURATION();

        uint256 targetRate = rewardAmount / 1000 / (duration);

        testIncentivizedVault.addRewardsToken(address(token));
        token.mint(address(this), rewardAmount);
        token.approve(address(testIncentivizedVault), rewardAmount);
        testIncentivizedVault.setRewardsInterval(address(token), start, start + duration, rewardAmount, DEFAULT_FEE_RECIPIENT);

        vm.startPrank(REGULAR_USER);
        token.mint(address(REGULAR_USER), depositAmount);
        token.approve(address(testIncentivizedVault), depositAmount);
        testIncentivizedVault.deposit(depositAmount, REGULAR_USER);
        vm.stopPrank();

        //@audit Borrow assets to trigger the condition that adjusts the `end` time to `MIN_CAMPAIGN_DURATION`
        vm.startPrank(REGULAR_USER);
        $.collateralToken.mint(address(REGULAR_USER), depositAmount);
        $.collateralToken.approve(address(testIncentivizedVault.dahlia()), depositAmount);
        testIncentivizedVault.dahlia().supplyAndBorrow($.marketId, depositAmount, 1, REGULAR_USER, REGULAR_USER);
        vm.stopPrank();

        //@audit Move to the last day of the reward distribution to simulate edge case
        skip(activeRewardPeriod);
        (uint32 actualStart, uint32 actualEnd, uint96 actualRate) = testIncentivizedVault.rewardToInterval(address(token));

        assertEq(actualStart, start);
        //@audit since there is borrowed assets end is increased to min duration
        assertEq(actualEnd, block.timestamp + testIncentivizedVault.MIN_CAMPAIGN_DURATION());
        assertGt(actualRate, targetRate);

        uint256 lendRate = testIncentivizedVault.dahlia().previewLendRateAfterDeposit($.marketId, 1e18);
        assertEq(lendRate, 0);

        //@audit Despite the lend rate being 0, the combined reward rate passes validation due to the artificially extended end time
        uint256 afterRate = testIncentivizedVault.previewRateAfterDeposit(address(token), 1e18);
        assertLt(afterRate, targetRate, "It should be smaller than the target rate as we approach the end of the period");

        //@audit :
        // - If the reward asset is the DEPOSIT_ASSET, the special condition in `rewardToInterval` for borrowed assets
        //   forces the `end` time to extend to `MIN_CAMPAIGN_DURATION`, even if there is very little time left for rewards.
        // - This allows the system to compute a combined reward rate (`previewRateAfterDeposit`) that exceeds the `targetRate`,
        //   even though the lending rate is effectively 0 and the remaining duration is insufficient for meaningful rewards.
        // - User funds are improperly allocated to this vault, as the reward rate condition passes even though it is artificially inflated.
    }
}
