// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Points} from "@royco/Points.sol";
import {PointsFactory} from "@royco/PointsFactory.sol";
import {IWrappedVault} from "@royco/interfaces/IWrappedVault.sol";
import {SafeCast} from "@royco/libraries/SafeCast.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {Types} from "src/core/types/Types.sol";
import {WrappedVaultFactory} from "src/royco/contracts/WrappedVaultFactory.sol";

/// @title WrappedVault
/// @author Jack Corddry, CopyPaste, Shivaansh Kapoor
/// @dev A token inheriting from ERC20Rewards will reward token holders with a rewards token.
/// The rewarded amount will be a fixed wei per second, distributed proportionally to token holders
/// by the size of their holdings.
contract WrappedVault is Owned, ERC20, IWrappedVault {
    using SafeTransferLib for ERC20;
    using SafeCast for uint256;
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               INTERFACE
    //////////////////////////////////////////////////////////////*/

    event RewardsSet(
        address reward,
        uint32 start,
        uint32 end,
        uint256 rate,
        uint256 totalRewards,
        uint256 protocolFee,
        uint256 frontendFee
    );
    event RewardsPerTokenUpdated(address reward, uint256 accumulated);
    event UserRewardsUpdated(address reward, address user, uint256 accumulated, uint256 checkpoint);
    event Claimed(address reward, address user, address receiver, uint256 claimed);
    event FeesClaimed(address claimant, address incentiveToken);
    event RewardsTokenAdded(address reward);
    event FrontendFeeUpdated(uint256 frontendFee);

    error MaxRewardsReached();
    error TooFewShares();
    error VaultNotAuthorizedToRewardPoints();
    error InvalidInterval();
    error IntervalInProgress();
    error IntervalScheduled();
    error NoIntervalInProgress();
    error RateCannotDecrease();
    error DuplicateRewardToken();
    error FrontendFeeBelowMinimum();
    error NoZeroRateAllowed();
    error InvalidReward();
    error InvalidWithdrawal();
    error InvalidIntervalDuration();
    error NotOwnerOfVaultOrApproved();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:field start The start time of the rewards schedule
    /// @custom:field end   The end time of the rewards schedule
    /// @custom:field rate  The reward rate split among all token holders a second in Wei
    struct RewardsInterval {
        uint32 start;
        uint32 end;
        uint96 rate;
    }

    /// @custom:field accumulated The accumulated rewards per token for the intervaled, scaled up by WAD
    /// @custom:field lastUpdated THe last time rewards per token (accumulated) was updated
    struct RewardsPerToken {
        uint256 accumulated;
        uint32 lastUpdated;
    }

    /// @custom:field accumulated Rewards accumulated for the user until the checkpoint
    /// @custom:field checkpoint  RewardsPerToken the last time the user rewards were updated
    struct UserRewards {
        uint256 accumulated;
        uint256 checkpoint;
    }

    /// @dev The max amount of reward campaigns a user can be involved in
    uint256 public constant MAX_REWARDS = 20;
    /// @dev The minimum duration a reward campaign must last
    uint256 public constant MIN_CAMPAIGN_DURATION = 1 weeks;
    /// @dev The minimum lifespan of an extended campaign
    uint256 public constant MIN_CAMPAIGN_EXTENSION = 1 weeks;

    /// @dev The underlying asset being deposited into the vault
    ERC20 internal immutable DEPOSIT_ASSET;
    /// @dev The address of the canonical points program factory
    PointsFactory public immutable POINTS_FACTORY;
    /// @dev The address of the canonical WrappedVault factory
    WrappedVaultFactory public immutable ERC4626I_FACTORY;

    /// @dev The fee taken by the referring frontend, out of WAD
    uint256 public frontendFee;

    /// @dev Tokens {and,or} Points campaigns used as rewards
    address[] public rewards;
    /// @dev Maps a reward address to whether it has been added via addRewardsToken
    mapping(address => bool) public isReward;
    /// @dev Maps a reward to the interval in which rewards are distributed over
    mapping(address => RewardsInterval) internal rewardToIntervalData;
    /// @dev maps a reward (either token or points) to the accumulator to track reward distribution
    mapping(address => RewardsPerToken) public rewardToRPT;
    /// @dev Maps a reward (either token or points) to a user, and that users accumulated rewards
    mapping(address => mapping(address => UserRewards)) public rewardToUserToAR;
    /// @dev Maps a reward (either token or points) to a claimant, to accrued fees
    mapping(address => mapping(address => uint256)) public rewardToClaimantToFees;

    IDahlia public immutable dahlia;
    Types.MarketId public immutable marketId; // 4 bytes

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _owner The owner of the incentivized vault
    /// @param _name The name of the incentivized vault token
    /// @param _symbol The symbol to use for the incentivized vault token
    /// @param _dahlia The address of the dahlia contract
    /// @param _decimals The decimals of the underlying asset
    /// @param _marketId The market id in dahlia
    /// @param initialFrontendFee The initial fee set for the frontend out of WAD
    /// @param pointsFactory The canonical factory responsible for deploying all points programs
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _dahlia,
        uint8 _decimals,
        Types.MarketId _marketId,
        address _asset,
        uint256 initialFrontendFee,
        address pointsFactory
    ) Owned(_owner) ERC20(_name, _symbol, _decimals) {
        ERC4626I_FACTORY = WrappedVaultFactory(msg.sender);
        if (initialFrontendFee < ERC4626I_FACTORY.minimumFrontendFee()) {
            revert FrontendFeeBelowMinimum();
        }

        frontendFee = initialFrontendFee;
        dahlia = IDahlia(_dahlia);
        marketId = _marketId;
        DEPOSIT_ASSET = ERC20(_asset);
        POINTS_FACTORY = PointsFactory(pointsFactory);

        _mint(address(0), 10_000); // Burn 10,000 wei to stop 'first share' front running attacks on depositors

        DEPOSIT_ASSET.approve(_dahlia, type(uint256).max);
    }

    // TODO: add external rewardToInterval to fake end to be block.timestamp + MIN_CAMPAIGN_DURATION for the loan asset only
    // if there are some borrowers
    function rewardToInterval(address reward) external view returns (uint32 start, uint32 end, uint96 rate) {
        start = rewardToIntervalData[reward].start;
        end = rewardToIntervalData[reward].end;
        rate = rewardToIntervalData[reward].rate;
        if (reward == address(DEPOSIT_ASSET)) {
            if (dahlia.getMarket(marketId).totalBorrowAssets > 0) {
                end = uint32(block.timestamp + MIN_CAMPAIGN_DURATION);
            }
        }
    }

    /// @param rewardsToken The new reward token / points program to be used as incentives
    function addRewardsToken(address rewardsToken) public payable onlyOwner {
        // Check if max rewards offered limit has been reached
        if (rewards.length == MAX_REWARDS) {
            revert MaxRewardsReached();
        }

        if (rewardsToken == address(dahlia)) {
            revert InvalidReward();
        }

        if (rewardsToken == address(this)) {
            revert InvalidReward();
        }

        // Check if reward has already been added to the incentivized vault
        if (isReward[rewardsToken]) {
            revert DuplicateRewardToken();
        }

        // Check if vault is authorized to award points if reward is a points program
        if (POINTS_FACTORY.isPointsProgram(rewardsToken) && !Points(rewardsToken).isAllowedVault(address(this))) {
            revert VaultNotAuthorizedToRewardPoints();
        }
        rewards.push(rewardsToken);
        isReward[rewardsToken] = true;
        emit RewardsTokenAdded(rewardsToken);
    }

    /// @param newFrontendFee The new front-end fee out of WAD
    function setFrontendFee(uint256 newFrontendFee) public payable onlyOwner {
        if (newFrontendFee < ERC4626I_FACTORY.minimumFrontendFee()) {
            revert FrontendFeeBelowMinimum();
        }
        frontendFee = newFrontendFee;
        emit FrontendFeeUpdated(newFrontendFee);
    }

    /// @param to The address to send all fees owed to msg.sender to
    function claimFees(address to) external payable {
        for (uint256 i = 0; i < rewards.length; i++) {
            address reward = rewards[i];
            claimFees(to, reward);
        }
    }

    /// @param to The address to send all fees owed to msg.sender to
    /// @param reward The reward token / points program to claim fees from
    function claimFees(address to, address reward) public payable {
        if (!isReward[reward]) {
            revert InvalidReward();
        }

        uint256 owed = rewardToClaimantToFees[reward][msg.sender];
        delete rewardToClaimantToFees[reward][msg.sender];
        pushReward(reward, to, owed);
        emit FeesClaimed(msg.sender, reward);
    }

    /// @param reward The reward token / points program
    /// @param from The address to pull rewards from
    /// @param amount The amount of rewards to deduct from the user
    function pullReward(address reward, address from, uint256 amount) internal {
        if (POINTS_FACTORY.isPointsProgram(reward)) {
            if (!Points(reward).isAllowedVault(address(this))) {
                revert VaultNotAuthorizedToRewardPoints();
            }
        } else {
            ERC20(reward).safeTransferFrom(from, address(this), amount);
        }
    }

    /// @param reward The reward token / points program
    /// @param to The address to send rewards to
    /// @param amount The amount of rewards to deduct from the user
    function pushReward(address reward, address to, uint256 amount) internal {
        // If owed is 0, there is nothing to claim. Check allows any loop calling pushReward to continue without reversion.
        if (amount == 0) {
            return;
        }
        if (POINTS_FACTORY.isPointsProgram(reward)) {
            Points(reward).award(to, amount);
        } else {
            ERC20(reward).safeTransfer(to, amount);
        }
    }

    /// @notice Extend the rewards interval for a given rewards campaign by adding more rewards
    /// @param reward The reward token / points campaign to extend rewards for
    /// @param rewardsAdded The amount of rewards to add to the campaign
    /// @param newEnd The end date of the rewards campaign
    /// @param frontendFeeRecipient The address to reward for directing IP flow
    function extendRewardsInterval(address reward, uint256 rewardsAdded, uint256 newEnd, address frontendFeeRecipient)
        external
        payable
        onlyOwner
    {
        if (!isReward[reward]) {
            revert InvalidReward();
        }
        RewardsInterval storage rewardsInterval = rewardToIntervalData[reward];
        if (newEnd <= rewardsInterval.end) {
            revert InvalidInterval();
        }
        if (block.timestamp >= rewardsInterval.end) {
            revert NoIntervalInProgress();
        }
        _updateRewardsPerToken(reward);

        // Calculate fees
        uint256 frontendFeeTaken = rewardsAdded.mulWadDown(frontendFee);
        uint256 protocolFeeTaken = rewardsAdded.mulWadDown(ERC4626I_FACTORY.protocolFee());

        // Make fees available for claiming
        rewardToClaimantToFees[reward][frontendFeeRecipient] += frontendFeeTaken;
        rewardToClaimantToFees[reward][ERC4626I_FACTORY.protocolFeeRecipient()] += protocolFeeTaken;

        // Calculate the new rate
        uint256 rewardsAfterFee = rewardsAdded - frontendFeeTaken - protocolFeeTaken;

        uint32 newStart =
            block.timestamp > uint256(rewardsInterval.start) ? block.timestamp.toUint32() : rewardsInterval.start;

        if ((newEnd - newStart) < MIN_CAMPAIGN_EXTENSION) {
            revert InvalidIntervalDuration();
        }

        uint256 remainingRewards = rewardsInterval.rate * (rewardsInterval.end - newStart);
        uint256 rate = (rewardsAfterFee + remainingRewards) / (newEnd - newStart);

        if (rate < rewardsInterval.rate) {
            revert RateCannotDecrease();
        }

        rewardsInterval.start = newStart;
        rewardsInterval.end = newEnd.toUint32();
        rewardsInterval.rate = rate.toUint96();

        emit RewardsSet(
            reward,
            newStart,
            newEnd.toUint32(),
            rate,
            (rewardsAfterFee + remainingRewards),
            protocolFeeTaken,
            frontendFeeTaken
        );

        pullReward(reward, msg.sender, rewardsAdded);
    }

    /// @dev Set a rewards schedule
    /// @param reward The reward token or points program to set the interval for
    /// @param start The start timestamp of the interval
    /// @param end The end timestamp of the interval
    /// @param totalRewards The amount of rewards to distribute over the interval
    /// @param frontendFeeRecipient The address to reward the frontendFee
    function setRewardsInterval(
        address reward,
        uint256 start,
        uint256 end,
        uint256 totalRewards,
        address frontendFeeRecipient
    ) external payable onlyOwner {
        if (!isReward[reward]) {
            revert InvalidReward();
        }
        if (start >= end || end <= block.timestamp) {
            revert InvalidInterval();
        }
        if ((end - start) < MIN_CAMPAIGN_DURATION) {
            revert InvalidIntervalDuration();
        }

        RewardsInterval storage rewardsInterval = rewardToIntervalData[reward];
        RewardsPerToken storage rewardsPerToken = rewardToRPT[reward];

        // A new rewards program cannot be set if one is running
        if (block.timestamp.toUint32() >= rewardsInterval.start && block.timestamp.toUint32() <= rewardsInterval.end) {
            revert IntervalInProgress();
        }

        // A new rewards program cannot be set if one is scheduled to run in the future
        if (rewardsInterval.start > block.timestamp) {
            revert IntervalScheduled();
        }

        // Update the rewards per token so that we don't lose any rewards
        _updateRewardsPerToken(reward);

        // Calculate fees
        uint256 frontendFeeTaken = totalRewards.mulWadDown(frontendFee);
        uint256 protocolFeeTaken = totalRewards.mulWadDown(ERC4626I_FACTORY.protocolFee());

        // Make fees available for claiming
        rewardToClaimantToFees[reward][frontendFeeRecipient] += frontendFeeTaken;
        rewardToClaimantToFees[reward][ERC4626I_FACTORY.protocolFeeRecipient()] += protocolFeeTaken;

        // Calculate the rate
        uint256 rewardsAfterFee = totalRewards - frontendFeeTaken - protocolFeeTaken;
        uint256 rate = rewardsAfterFee / (end - start);

        if (rate == 0) {
            revert NoZeroRateAllowed();
        }

        rewardsInterval.start = start.toUint32();
        rewardsInterval.end = end.toUint32();
        rewardsInterval.rate = rate.toUint96();

        // If setting up a new rewards program, the rewardsPerToken.accumulated is used and built upon
        // New rewards start accumulating from the new rewards program start
        // Any unaccounted rewards from last program can still be added to the user rewards
        // Any unclaimed rewards can still be claimed
        rewardsPerToken.lastUpdated = start.toUint32();

        emit RewardsSet(
            reward,
            block.timestamp.toUint32(),
            rewardsInterval.end,
            rate,
            rewardsAfterFee,
            protocolFeeTaken,
            frontendFeeTaken
        );

        pullReward(reward, msg.sender, totalRewards);
    }

    /// @param reward The address of the reward for which campaign should be refunded
    function refundRewardsInterval(address reward) external payable onlyOwner {
        if (!isReward[reward]) {
            revert InvalidReward();
        }
        RewardsInterval memory rewardsInterval = rewardToIntervalData[reward];
        delete rewardToIntervalData[reward];
        if (block.timestamp >= rewardsInterval.start) {
            revert IntervalInProgress();
        }

        uint256 rewardsOwed = (rewardsInterval.rate * (rewardsInterval.end - rewardsInterval.start)) - 1; // Round down
        if (!POINTS_FACTORY.isPointsProgram(reward)) {
            ERC20(reward).safeTransfer(msg.sender, rewardsOwed);
        }
        emit RewardsSet(reward, 0, 0, 0, 0, 0, 0);
    }

    /// @notice Update the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked amount.
    function _calculateRewardsPerToken(
        RewardsPerToken memory rewardsPerTokenIn,
        RewardsInterval memory rewardsInterval_
    ) internal view returns (RewardsPerToken memory) {
        RewardsPerToken memory rewardsPerTokenOut =
            RewardsPerToken(rewardsPerTokenIn.accumulated, rewardsPerTokenIn.lastUpdated);

        // No changes if the program hasn't started
        if (block.timestamp < rewardsInterval_.start) {
            return rewardsPerTokenOut;
        }

        // No changes if the start value is zero
        if (rewardsInterval_.start == 0) {
            return rewardsPerTokenOut;
        }

        // Stop accumulating at the end of the rewards interval
        uint256 updateTime = block.timestamp < rewardsInterval_.end ? block.timestamp : rewardsInterval_.end;
        uint256 elapsed = updateTime - rewardsPerTokenIn.lastUpdated;

        // No changes if no time has passed
        if (elapsed == 0) {
            return rewardsPerTokenOut;
        }
        rewardsPerTokenOut.lastUpdated = updateTime.toUint32();

        // If there are no stakers we just change the last update time, the rewards for intervals without stakers are not accumulated

        uint256 elapsedWAD = elapsed * 1e18;
        // Calculate and update the new value of the accumulator.
        rewardsPerTokenOut.accumulated =
            (rewardsPerTokenIn.accumulated + (elapsedWAD.mulDivDown(rewardsInterval_.rate, totalSupply))); // The
            // rewards per token are scaled up for precision

        return rewardsPerTokenOut;
    }

    /// @notice Calculate the rewards accumulated by a stake between two checkpoints.
    function _calculateUserRewards(uint256 stake_, uint256 earlierCheckpoint, uint256 latterCheckpoint)
        internal
        pure
        returns (uint256)
    {
        return stake_ * (latterCheckpoint - earlierCheckpoint) / 1e18; // We must scale down the rewards by the precision factor
    }

    /// @notice Update and return the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked
    /// amount.
    function _updateRewardsPerToken(address reward) internal returns (RewardsPerToken memory) {
        RewardsInterval storage rewardsInterval = rewardToIntervalData[reward];
        RewardsPerToken memory rewardsPerTokenIn = rewardToRPT[reward];
        RewardsPerToken memory rewardsPerTokenOut = _calculateRewardsPerToken(rewardsPerTokenIn, rewardsInterval);

        // We skip the storage changes if already updated in the same block, or if the program has ended and was updated at the end
        if (rewardsPerTokenIn.lastUpdated == rewardsPerTokenOut.lastUpdated) {
            return rewardsPerTokenOut;
        }

        rewardToRPT[reward] = rewardsPerTokenOut;
        emit RewardsPerTokenUpdated(reward, rewardsPerTokenOut.accumulated);

        return rewardsPerTokenOut;
    }

    /// @param user The user to update rewards for
    function _updateUserRewards(address user) internal {
        for (uint256 i = 0; i < rewards.length; i++) {
            address reward = rewards[i];
            _updateUserRewards(reward, user);
        }
    }

    /// @notice Calculate and store current rewards for an user. Checkpoint the rewardsPerToken value with the user.
    /// @param reward The reward token / points program to update rewards for
    /// @param user The user to update rewards for
    function _updateUserRewards(address reward, address user) internal returns (UserRewards memory) {
        RewardsPerToken memory rewardsPerToken_ = _updateRewardsPerToken(reward);
        UserRewards memory userRewards_ = rewardToUserToAR[reward][user];

        // We skip the storage changes if there are no changes to the rewards per token accumulator
        if (userRewards_.checkpoint == rewardsPerToken_.accumulated) {
            return userRewards_;
        }

        // Calculate and update the new value user reserves.
        userRewards_.accumulated +=
            _calculateUserRewards(balanceOf[user], userRewards_.checkpoint, rewardsPerToken_.accumulated).toUint128();
        userRewards_.checkpoint = rewardsPerToken_.accumulated;

        rewardToUserToAR[reward][user] = userRewards_;
        emit UserRewardsUpdated(reward, user, userRewards_.accumulated, userRewards_.checkpoint);

        return userRewards_;
    }

    /// @dev Mint tokens, after accumulating rewards for an user and update the rewards per token accumulator.
    function _mint(address to, uint256 amount) internal virtual override {
        _updateUserRewards(to);
        super._mint(to, amount);
    }

    /// @dev Burn tokens, after accumulating rewards for an user and update the rewards per token accumulator.
    function _burn(address from, uint256 amount) internal virtual override {
        _updateUserRewards(from);
        super._burn(from, amount);
    }

    /// @notice Claim rewards for an user
    function _claim(address reward, address from, address to, uint256 amount) internal virtual {
        _updateUserRewards(reward, from);
        rewardToUserToAR[reward][from].accumulated -= amount.toUint128();
        if (reward == address(DEPOSIT_ASSET)) {
            dahlia.claimInterest(marketId, from, to);
        }
        pushReward(reward, to, amount);
        emit Claimed(reward, from, to, amount);
    }

    /// @dev Transfer tokens, after updating rewards for source and destination.
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _updateUserRewards(msg.sender);
        _updateUserRewards(to);
        return super.transfer(to, amount);
    }

    /// @dev Transfer tokens, after updating rewards for source and destination.
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _updateUserRewards(from);
        _updateUserRewards(to);
        return super.transferFrom(from, to, amount);
    }

    /// @notice Allows the owner to claim the rewards from the burned shares
    /// @param to The address to send all rewards owed to the owner to
    /// @param reward The reward token / points program to claim rewards from
    function ownerClaim(address to, address reward) public payable onlyOwner {
        _claim(reward, address(0), to, currentUserRewards(reward, address(0)));
    }

    /// @notice Claim all rewards for the caller
    /// @param to The address to send the rewards to
    function claim(address to) public payable {
        for (uint256 i = 0; i < rewards.length; i++) {
            address reward = rewards[i];
            _claim(reward, msg.sender, to, currentUserRewards(reward, msg.sender));
        }
    }

    /// @param to The address to send the rewards to
    /// @param reward The reward token / points program to claim rewards from
    function claim(address to, address reward) public payable {
        if (!isReward[reward]) {
            revert InvalidReward();
        }
        _claim(reward, msg.sender, to, currentUserRewards(reward, msg.sender));
        // TODO: dahlia.claim() to claim earned interest
    }

    /// @notice Calculate and return current rewards per token.
    function currentRewardsPerToken(address reward) public view returns (uint256) {
        return _calculateRewardsPerToken(rewardToRPT[reward], rewardToIntervalData[reward]).accumulated;
    }

    /// @notice Calculate and return current rewards for a user.
    /// @dev This repeats the logic used on transactions, but doesn't update the storage.
    function currentUserRewards(address reward, address user) public view returns (uint256) {
        UserRewards memory accumulatedRewards_ = rewardToUserToAR[reward][user];
        RewardsPerToken memory rewardsPerToken_ =
            _calculateRewardsPerToken(rewardToRPT[reward], rewardToIntervalData[reward]);
        return accumulatedRewards_.accumulated
            + _calculateUserRewards(balanceOf[user], accumulatedRewards_.checkpoint, rewardsPerToken_.accumulated);
    }

    /// @notice Calculates the rate a user would receive in rewards after depositing assets
    /// @return The rate of rewards, measured in wei of rewards token per wei of assets per second, scaled up by 1e18 to avoid precision loss
    function previewRateAfterDeposit(address reward, uint256 assets) public view returns (uint256) {
        RewardsInterval memory rewardsInterval = rewardToIntervalData[reward];
        if (rewardsInterval.start > block.timestamp || block.timestamp >= rewardsInterval.end) {
            return 0;
        }
        uint256 shares = previewDeposit(assets);

        uint256 rewardsRate = (uint256(rewardsInterval.rate) * shares / (totalSupply + shares)) * 1e18 / assets;
        // TODO: for x call dahlia.getLastStateAfterDeposit(assets)
        if (reward == address(DEPOSIT_ASSET)) {
            uint256 dahliaRate = dahlia.previewLendRateAfterDeposit(marketId, assets);
            rewardsRate += dahliaRate;
        }
        return rewardsRate;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IWrappedVault
    function asset() external view returns (address _asset) {
        return address(DEPOSIT_ASSET);
    }

    /// @inheritdoc IWrappedVault
    function totalAssets() public view returns (uint256) {
        return dahlia.getMarket(marketId).totalLendAssets;
    }

    /**
     * @dev See {IERC4626-balanceOf}.
     */
    function balanceOfDahlia(address account) public view returns (uint256 lendShares) {
        return dahlia.getMarketUserPosition(marketId, account).lendShares;
    }

    /// @notice safeDeposit allows a user to specify a minimum amount of shares out to avoid any
    /// slippage in the deposit
    /// @param assets The amount of assets to deposit
    /// @param receiver The address to mint the shares to
    /// @param minShares The minimum amount of shares to mint
    function safeDeposit(uint256 assets, address receiver, uint256 minShares) public returns (uint256 shares) {
        shares = _deposit(msg.sender, receiver, assets);
        if (shares < minShares) {
            revert TooFewShares();
        }
    }

    /// @inheritdoc IWrappedVault
    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = _deposit(msg.sender, receiver, assets);
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address caller, address receiver, uint256 assets) internal returns (uint256 shares) {
        DEPOSIT_ASSET.safeTransferFrom(caller, address(this), assets);
        (shares) = dahlia.lend(marketId, assets, receiver, bytes(""));
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IWrappedVault
    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = previewMint(shares);
        _deposit(msg.sender, receiver, assets); // TODO: should we compare shares with actual shares?
    }

    /// @inheritdoc IWrappedVault
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 expectedShares) {
        expectedShares = previewWithdraw(assets);
        uint256 actualAssets = _withdraw(msg.sender, expectedShares, receiver, owner);

        if (assets != actualAssets) {
            revert InvalidWithdrawal();
        }

        emit Withdraw(msg.sender, receiver, owner, assets, expectedShares);
    }

    /// @inheritdoc IWrappedVault
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 _assets) {
        uint256 assets = previewRedeem(shares);
        (_assets) = _withdraw(msg.sender, shares, receiver, owner);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _withdraw(address caller, uint256 shares, address receiver, address owner)
        internal
        virtual
        returns (uint256 _assets)
    {
        if (caller != owner) {
            uint256 allowed = allowance[owner][caller]; // Saves gas for limited approvals.
            if (shares > allowed) {
                revert NotOwnerOfVaultOrApproved();
            }
            if (allowed != type(uint256).max) {
                allowance[owner][caller] = allowed - shares;
            }
        }

        _burn(owner, shares);

        (_assets) = dahlia.withdraw(marketId, shares, owner, receiver);
    }

    /// @inheritdoc IWrappedVault
    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        shares = previewDeposit(assets);
    }

    /// @inheritdoc IWrappedVault
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = previewRedeem(shares);
    }

    /// @inheritdoc IWrappedVault
    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        maxAssets = type(uint256).max; // TODO this should 1e26
    }

    /// @inheritdoc IWrappedVault
    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        Types.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toSharesDown(assets, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxMint(address) external pure returns (uint256 maxShares) {
        maxShares = type(uint256).max; // TODO 1e32?
    }

    /// @inheritdoc IWrappedVault
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        Types.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toAssetsUp(shares, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxWithdraw(address addr) external view returns (uint256 maxAssets) {
        maxAssets = convertToAssets(balanceOfDahlia(addr));
    }

    /// @inheritdoc IWrappedVault
    function previewWithdraw(uint256 assets) public view virtual returns (uint256 shares) {
        Types.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toSharesUp(assets, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxRedeem(address addr) external view returns (uint256 maxShares) {
        maxShares = balanceOfDahlia(addr);
    }

    /// @inheritdoc IWrappedVault
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        Types.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toAssetsDown(shares, market.totalLendAssets, market.totalLendShares);
    }
}
