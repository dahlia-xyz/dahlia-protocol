// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Points } from "@royco/Points.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { SafeCast } from "@royco/libraries/SafeCast.sol";
import { Ownable } from "@solady/auth/Ownable.sol";
import { FixedPointMathLib as SoladyMath } from "@solady/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";
import { InitializableERC20 } from "src/royco/periphery/InitializableERC20.sol";

/// @title WrappedVault
/// @author Jack Corddry, CopyPaste, Shivaansh Kapoor
/// @dev A token inheriting from ERC20Rewards will reward token holders with a rewards token.
/// The rewarded amount will be a fixed wei per second, distributed proportionally to token holders
/// by the size of their holdings.
contract WrappedVault is Ownable, InitializableERC20, IWrappedVault {
    using SafeTransferLib for ERC20;
    using SafeCast for uint256;
    using FixedPointMathLib for uint256;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               INTERFACE
    //////////////////////////////////////////////////////////////*/

    event RewardsSet(address reward, uint32 start, uint32 end, uint256 rate, uint256 totalRewards, uint256 protocolFee, uint256 frontendFee);
    event RewardsPerTokenUpdated(address reward, uint256 accumulated);
    event UserRewardsUpdated(address reward, address user, uint256 accumulated, uint256 checkpoint);
    event Claimed(address reward, address user, address receiver, uint256 claimed);
    event FeesClaimed(address claimant, address incentiveToken, uint256 owed);
    event RewardsTokenAdded(address reward);
    event FrontendFeeUpdated(uint256 frontendFee);

    error MaxRewardsReached();
    error TooFewShares();
    error VaultNotAuthorizedToRewardPoints();
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
    error IntervalEndBeforeStart();
    error IntervalEndInPast();
    error CannotShortenInterval();
    error IntervalStartIsZero();

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

    /// @custom:field accumulated The accumulated rewards per token for the interval, scaled up by WAD
    /// @custom:field lastUpdated The last time rewards per token (accumulated) was updated
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
    /// @dev RewardsPerToken.accumulated is scaled up to prevent loss of incentives
    uint256 public constant RPT_PRECISION = 1e27;

    /// @dev The underlying asset being deposited into the vault
    ERC20 private DEPOSIT_ASSET;
    /// @dev The address of the canonical points program factory
    PointsFactory public POINTS_FACTORY;
    /// @dev The address of the canonical WrappedVault factory
    WrappedVaultFactory public WRAPPED_VAULT_FACTORY;

    /// @dev The fee taken by the referring frontend, out of WAD
    uint256 public frontendFee;

    /// @dev Tokens {and,or} Points campaigns used as rewards
    address[] public rewards;
    /// @dev Maps a reward address to whether it has been added via addRewardsToken
    mapping(address => bool) public isReward;
    /// @dev Maps a reward to the interval in which rewards are distributed over
    mapping(address => RewardsInterval) internal _rewardToInterval;
    /// @dev maps a reward (either token or points) to the accumulator to track reward distribution
    mapping(address => RewardsPerToken) public rewardToRPT;
    /// @dev Maps a reward (either token or points) to a user, and that users accumulated rewards
    mapping(address => mapping(address => UserRewards)) public rewardToUserToAR;
    /// @dev Maps a reward (either token or points) to a claimant, to accrued fees
    mapping(address => mapping(address => uint256)) public rewardToClaimantToFees;

    IDahlia public dahlia;
    IDahlia.MarketId public marketId; // 4 bytes

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @param _owner The owner of the incentivized vault
    /// @param _name The name of the incentivized vault token
    /// @param _symbol The symbol to use for the incentivized vault token
    /// @param _dahlia The address of the dahlia contract
    /// @param _decimals The decimals of the underlying asset
    /// @param _marketId The market id in dahlia
    /// @param initialFrontendFee The initial fee set for the frontend out of WAD
    /// @param pointsFactory The canonical factory responsible for deploying all points programs
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _dahlia,
        uint8 _decimals,
        IDahlia.MarketId _marketId,
        address _asset,
        uint256 initialFrontendFee,
        address pointsFactory
    ) external initializer {
        _initializeOwner(_owner);
        _initializeERC20(_name, _symbol, _decimals);

        WRAPPED_VAULT_FACTORY = WrappedVaultFactory(msg.sender);
        if (initialFrontendFee < WRAPPED_VAULT_FACTORY.minimumFrontendFee()) revert FrontendFeeBelowMinimum();

        frontendFee = initialFrontendFee;
        dahlia = IDahlia(_dahlia);
        marketId = _marketId;
        DEPOSIT_ASSET = ERC20(_asset);
        POINTS_FACTORY = PointsFactory(pointsFactory);

        //_mint(address(0), 10_000 * SharesMathLib.SHARES_OFFSET); // Burn 10,000 wei to stop 'first share' front running attacks on depositors

        DEPOSIT_ASSET.approve(_dahlia, type(uint256).max);
    }

    /// @notice Returns parameters of reward internal
    /// @param reward The reward token / points program
    /// @return start Start time in seconds
    /// @return end End time in seconds
    /// @return rate Rewards rate per second
    function rewardToInterval(address reward) external view returns (uint32 start, uint32 end, uint96 rate) {
        start = _rewardToInterval[reward].start;
        end = _rewardToInterval[reward].end;
        rate = _rewardToInterval[reward].rate;
        if (reward == address(DEPOSIT_ASSET)) {
            uint256 minEnd = block.timestamp + MIN_CAMPAIGN_DURATION;
            if (end < minEnd && dahlia.getMarket(marketId).totalBorrowAssets > 0) {
                end = uint32(minEnd);
            }
        }
    }

    /// @param rewardsToken The new reward token / points program to be used as incentives
    function addRewardsToken(address rewardsToken) public payable onlyOwner {
        // Check if max rewards offered limit has been reached
        if (rewards.length == MAX_REWARDS) revert MaxRewardsReached();

        if (rewardsToken == address(this)) revert InvalidReward();

        // Check if reward has already been added to the incentivized vault
        if (isReward[rewardsToken]) revert DuplicateRewardToken();

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
        if (newFrontendFee < WRAPPED_VAULT_FACTORY.minimumFrontendFee()) revert FrontendFeeBelowMinimum();
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
        if (!isReward[reward]) revert InvalidReward();

        uint256 owed = rewardToClaimantToFees[reward][msg.sender];
        delete rewardToClaimantToFees[reward][msg.sender];
        _pushReward(reward, to, owed);
        emit FeesClaimed(msg.sender, reward, owed);
    }

    /// @param reward The reward token / points program
    /// @param from The address to pull rewards from
    /// @param amount The amount of rewards to deduct from the user
    function _pullReward(address reward, address from, uint256 amount) internal {
        if (POINTS_FACTORY.isPointsProgram(reward)) {
            if (!Points(reward).isAllowedVault(address(this))) revert VaultNotAuthorizedToRewardPoints();
        } else {
            ERC20(reward).safeTransferFrom(from, address(this), amount);
        }
    }

    /// @param reward The reward token / points program
    /// @param to The address to send rewards to
    /// @param amount The amount of rewards to deduct from the user
    function _pushReward(address reward, address to, uint256 amount) internal {
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

    /// @notice Extend the rewards interval for a given rewards campaign by adding more rewards, must run for at least 1 more week
    /// @param reward The reward token / points campaign to extend rewards for
    /// @param rewardsAdded The amount of rewards to add to the campaign
    /// @param newEnd The end date of the rewards campaign, must be more than 1 week after the updated campaign start
    /// @param frontendFeeRecipient The address to reward for directing IP flow
    function extendRewardsInterval(address reward, uint256 rewardsAdded, uint256 newEnd, address frontendFeeRecipient) external payable onlyOwner {
        if (!isReward[reward]) revert InvalidReward();
        RewardsInterval storage rewardsInterval = _rewardToInterval[reward];
        if (newEnd <= rewardsInterval.end) revert CannotShortenInterval();
        if (block.timestamp >= rewardsInterval.end) revert NoIntervalInProgress();
        _updateRewardsPerToken(reward);

        // Calculate fees
        uint256 frontendFeeTaken = rewardsAdded.mulWadDown(frontendFee);
        uint256 protocolFeeTaken = rewardsAdded.mulWadDown(WRAPPED_VAULT_FACTORY.protocolFee());

        // Make fees available for claiming
        rewardToClaimantToFees[reward][frontendFeeRecipient] += frontendFeeTaken;
        rewardToClaimantToFees[reward][WRAPPED_VAULT_FACTORY.protocolFeeRecipient()] += protocolFeeTaken;

        // Calculate the new rate

        uint32 newStart = block.timestamp > uint256(rewardsInterval.start) ? block.timestamp.toUint32() : rewardsInterval.start;

        if ((newEnd - newStart) < MIN_CAMPAIGN_DURATION) revert InvalidIntervalDuration();

        uint256 remainingRewards = rewardsInterval.rate * (rewardsInterval.end - newStart);
        uint256 rate = (rewardsAdded - frontendFeeTaken - protocolFeeTaken + remainingRewards) / (newEnd - newStart);
        rewardsAdded = rate * (newEnd - newStart) - remainingRewards + frontendFeeTaken + protocolFeeTaken;

        if (rate < rewardsInterval.rate) revert RateCannotDecrease();

        rewardsInterval.start = newStart;
        rewardsInterval.end = newEnd.toUint32();
        rewardsInterval.rate = rate.toUint96();

        emit RewardsSet(reward, newStart, newEnd.toUint32(), rate, (rate * (newEnd - newStart)), protocolFeeTaken, frontendFeeTaken);

        _pullReward(reward, msg.sender, rewardsAdded);
    }

    /// @dev Set a rewards schedule
    /// @notice Starts a rewards schedule, must run for at least 1 week
    /// @param reward The reward token or points program to set the interval for
    /// @param start The start timestamp of the interval
    /// @param end The end timestamp of the interval, interval must be more than 1 week long
    /// @param totalRewards The amount of rewards to distribute over the interval
    /// @param frontendFeeRecipient The address to reward the frontendFee
    function setRewardsInterval(address reward, uint256 start, uint256 end, uint256 totalRewards, address frontendFeeRecipient) external payable onlyOwner {
        if (!isReward[reward]) revert InvalidReward();
        if (start >= end) revert IntervalEndBeforeStart();
        if (end <= block.timestamp) revert IntervalEndBeforeStart();
        if (start == 0) revert IntervalEndBeforeStart();
        if ((end - start) < MIN_CAMPAIGN_DURATION) revert InvalidIntervalDuration();

        RewardsInterval storage rewardsInterval = _rewardToInterval[reward];
        RewardsPerToken storage rewardsPerToken = rewardToRPT[reward];

        // A new rewards program cannot be set if one is running
        if (block.timestamp.toUint32() >= rewardsInterval.start && block.timestamp.toUint32() <= rewardsInterval.end) revert IntervalInProgress();

        // A new rewards program cannot be set if one is scheduled to run in the future
        if (rewardsInterval.start > block.timestamp) revert IntervalScheduled();

        // Update the rewards per token so that we don't lose any rewards
        _updateRewardsPerToken(reward);

        // Calculate fees
        uint256 frontendFeeTaken = totalRewards.mulWadDown(frontendFee);
        uint256 protocolFeeTaken = totalRewards.mulWadDown(WRAPPED_VAULT_FACTORY.protocolFee());

        // Make fees available for claiming
        rewardToClaimantToFees[reward][frontendFeeRecipient] += frontendFeeTaken;
        rewardToClaimantToFees[reward][WRAPPED_VAULT_FACTORY.protocolFeeRecipient()] += protocolFeeTaken;

        // Calculate the rate
        uint256 rate = (totalRewards - frontendFeeTaken - protocolFeeTaken) / (end - start);

        if (rate == 0) revert NoZeroRateAllowed();
        totalRewards = rate * (end - start) + frontendFeeTaken + protocolFeeTaken;

        rewardsInterval.start = start.toUint32();
        rewardsInterval.end = end.toUint32();
        rewardsInterval.rate = rate.toUint96();

        // If setting up a new rewards program, the rewardsPerToken.accumulated is used and built upon
        // New rewards start accumulating from the new rewards program start
        // Any unaccounted rewards from last program can still be added to the user rewards
        // Any unclaimed rewards can still be claimed
        rewardsPerToken.lastUpdated = start.toUint32();

        emit RewardsSet(reward, rewardsInterval.start, rewardsInterval.end, rate, (rate * (end - start)), protocolFeeTaken, frontendFeeTaken);

        _pullReward(reward, msg.sender, totalRewards);
    }

    /// @param reward The address of the reward for which campaign should be refunded
    function refundRewardsInterval(address reward) external payable onlyOwner {
        if (!isReward[reward]) revert InvalidReward();
        RewardsInterval memory rewardsInterval = _rewardToInterval[reward];
        delete _rewardToInterval[reward];
        if (block.timestamp >= rewardsInterval.start) revert IntervalInProgress();

        uint256 rewardsOwed = (rewardsInterval.rate * (rewardsInterval.end - rewardsInterval.start)) - 1; // Round down
        if (!POINTS_FACTORY.isPointsProgram(reward)) {
            ERC20(reward).safeTransfer(msg.sender, rewardsOwed);
        }
        emit RewardsSet(reward, 0, 0, 0, 0, 0, 0);
    }

    /// @notice Update the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked amount.
    function _calculateRewardsPerToken(RewardsPerToken memory rewardsPerTokenIn, RewardsInterval memory rewardsInterval_)
        internal
        view
        returns (RewardsPerToken memory)
    {
        RewardsPerToken memory rewardsPerTokenOut = RewardsPerToken(rewardsPerTokenIn.accumulated, rewardsPerTokenIn.lastUpdated);

        // No changes if the program hasn't started
        if (block.timestamp < rewardsInterval_.start) return rewardsPerTokenOut;

        // No changes if the start value is zero
        if (rewardsInterval_.start == 0) return rewardsPerTokenOut;

        // Stop accumulating at the end of the rewards interval
        uint256 updateTime = block.timestamp < rewardsInterval_.end ? block.timestamp : rewardsInterval_.end;
        uint256 elapsed = updateTime - rewardsPerTokenIn.lastUpdated;

        // No changes if no time has passed
        if (elapsed == 0) return rewardsPerTokenOut;

        // No changes if there are no stakers
        uint256 _totalPrincipal = totalPrincipal();
        if (_totalPrincipal == 0) return rewardsPerTokenOut;

        rewardsPerTokenOut.lastUpdated = updateTime.toUint32();

        // If there are no stakers we just change the last update time, the rewards for intervals without stakers are not accumulated

        // The rewards per token are scaled up for precision
        uint256 elapsedScaled = elapsed * RPT_PRECISION;
        // Calculate and update the new value of the accumulator.
        rewardsPerTokenOut.accumulated = (rewardsPerTokenIn.accumulated + (SoladyMath.fullMulDiv(elapsedScaled, rewardsInterval_.rate, _totalPrincipal)));

        return rewardsPerTokenOut;
    }

    /// @notice Calculate the rewards accumulated by a stake between two checkpoints.
    function _calculateUserRewards(uint256 stake_, uint256 earlierCheckpoint, uint256 latterCheckpoint) internal pure returns (uint256) {
        return stake_ * (latterCheckpoint - earlierCheckpoint) / RPT_PRECISION; // We must scale down the rewards by the precision factor
    }

    /// @notice Update and return the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked
    /// amount.
    function _updateRewardsPerToken(address reward) internal returns (RewardsPerToken memory) {
        RewardsInterval storage rewardsInterval = _rewardToInterval[reward];
        RewardsPerToken memory rewardsPerTokenIn = rewardToRPT[reward];
        RewardsPerToken memory rewardsPerTokenOut = _calculateRewardsPerToken(rewardsPerTokenIn, rewardsInterval);

        // We skip the storage changes if already updated in the same block, or if the program has ended and was updated at the end
        if (rewardsPerTokenIn.lastUpdated == rewardsPerTokenOut.lastUpdated) return rewardsPerTokenOut;

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
        if (userRewards_.checkpoint == rewardsPerToken_.accumulated) return userRewards_;

        // Calculate and update the new value user reserves.
        userRewards_.accumulated += _calculateUserRewards(principal(user), userRewards_.checkpoint, rewardsPerToken_.accumulated).toUint128();
        userRewards_.checkpoint = rewardsPerToken_.accumulated;

        rewardToUserToAR[reward][user] = userRewards_;
        emit UserRewardsUpdated(reward, user, userRewards_.accumulated, userRewards_.checkpoint);

        return userRewards_;
    }

    /// @dev Mint tokens, after accumulating rewards for an user and update the rewards per token accumulator.
    //    function _mint(address to) internal {
    //        _updateUserRewards(to);
    //        super._mint(to, amount);
    //    }

    /// @dev Burn tokens, after accumulating rewards for an user and update the rewards per token accumulator.
    //    function _burn(address from) internal {
    //        _updateUserRewards(from);
    //        super._burn(from, amount);
    //    }

    /// @notice Claim rewards for an user
    function _claim(address reward, address from, address to, uint256 amount) internal virtual {
        _updateUserRewards(reward, from);
        rewardToUserToAR[reward][from].accumulated -= amount.toUint128();
        if (reward == address(DEPOSIT_ASSET)) {
            dahlia.claimInterest(marketId, to, from);
        }
        _pushReward(reward, to, amount);
        emit Claimed(reward, from, to, amount);
    }

    /// @dev Transfer tokens, after updating rewards for source and destination.
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @dev Transfer tokens, after updating rewards for source and destination.
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, amount);
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        _updateUserRewards(from);
        _updateUserRewards(to);
        dahlia.transferLendShares(marketId, from, to, amount);
        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @notice copied from OpenZeppelin ERC20.sol
     * @dev Updates `from` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address from, uint256 value) internal virtual {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, ERC20InsufficientAllowance(msg.sender, currentAllowance, value));
            unchecked {
                _approve(from, msg.sender, currentAllowance - value, false);
            }
        }
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
        if (!isReward[reward]) revert InvalidReward();
        _claim(reward, msg.sender, to, currentUserRewards(reward, msg.sender));
    }

    /// @notice Calculate and return current rewards per token.
    function currentRewardsPerToken(address reward) public view returns (uint256) {
        return _calculateRewardsPerToken(rewardToRPT[reward], _rewardToInterval[reward]).accumulated;
    }

    /// @notice Calculate and return current rewards for a user.
    /// @dev This repeats the logic used on transactions, but doesn't update the storage.
    function currentUserRewards(address reward, address user) public view returns (uint256) {
        UserRewards memory accumulatedRewards_ = rewardToUserToAR[reward][user];
        RewardsPerToken memory rewardsPerToken_ = _calculateRewardsPerToken(rewardToRPT[reward], _rewardToInterval[reward]);
        return accumulatedRewards_.accumulated + _calculateUserRewards(principal(user), accumulatedRewards_.checkpoint, rewardsPerToken_.accumulated);
    }

    /// @notice Calculates the rate a user would receive in rewards after depositing assets
    /// @return The rate of rewards, measured in wei of rewards token per wei of assets per second, scaled up by 1e18 to avoid precision loss
    function previewRateAfterDeposit(address reward, uint256 assets) public view returns (uint256) {
        RewardsInterval memory rewardsInterval = _rewardToInterval[reward];
        if (rewardsInterval.start > block.timestamp || block.timestamp >= rewardsInterval.end) return 0;

        // 18 decimals for reward token = lend token
        uint256 rewardsRate = (uint256(rewardsInterval.rate) * assets * 1e18 / (totalPrincipal() + assets)) / assets;

        // Account for interest rate accrued in Dahlia market
        if (reward == address(DEPOSIT_ASSET)) {
            // 18 decimals
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

    /// @inheritdoc IWrappedVault
    function principal(address account) public view returns (uint256) {
        return dahlia.getPosition(marketId, account).lendPrincipalAssets;
    }

    /// @inheritdoc IWrappedVault
    function totalPrincipal() public view returns (uint256) {
        return dahlia.getMarket(marketId).totalLendPrincipalAssets;
    }

    /// @dev See {IERC4626-balanceOf}.
    function totalSupply() public view returns (uint256 result) {
        return dahlia.getMarket(marketId).totalLendShares;
    }

    /// @dev See {IERC4626-balanceOf}.
    function balanceOf(address account) public view returns (uint256 lendShares) {
        return dahlia.getPosition(marketId, account).lendShares;
    }

    /// @notice safeDeposit allows a user to specify a minimum amount of shares out to avoid any
    /// slippage in the deposit
    /// @param assets The amount of assets to deposit
    /// @param receiver The address to mint the shares to
    /// @param minShares The minimum amount of shares to mint
    function safeDeposit(uint256 assets, address receiver, uint256 minShares) public returns (uint256 shares) {
        shares = _deposit(receiver, assets);
        if (shares < minShares) revert TooFewShares();
    }

    /// @inheritdoc IWrappedVault
    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = _deposit(receiver, assets);
    }

    /// @dev Deposit/mint common workflow.
    function _deposit(address receiver, uint256 assets) internal returns (uint256 shares) {
        DEPOSIT_ASSET.safeTransferFrom(msg.sender, address(this), assets);

        (shares) = dahlia.lend(marketId, assets, receiver);
        _updateUserRewards(receiver);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IWrappedVault
    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = previewMint(shares);
        _deposit(receiver, assets);
    }

    /// @inheritdoc IWrappedVault
    function withdraw(uint256 assets, address receiver, address from) external returns (uint256 expectedShares) {
        expectedShares = previewWithdraw(assets);
        uint256 actualAssets = _withdraw(msg.sender, expectedShares, receiver, from);

        if (assets != actualAssets) revert InvalidWithdrawal();

        emit Withdraw(msg.sender, receiver, from, assets, expectedShares);
    }

    /// @inheritdoc IWrappedVault
    function redeem(uint256 shares, address receiver, address from) external returns (uint256 assets) {
        (assets) = _withdraw(msg.sender, shares, receiver, from);

        emit Withdraw(msg.sender, receiver, from, assets, shares);
    }

    function _withdraw(address caller, uint256 shares, address receiver, address from) internal virtual returns (uint256 _assets) {
        if (caller != from) {
            uint256 allowed = allowance[from][caller]; // Saves gas for limited approvals.
            if (shares > allowed) revert NotOwnerOfVaultOrApproved();
            if (allowed != type(uint256).max) allowance[from][caller] = allowed - shares;
        }

        _updateUserRewards(from);

        (_assets) = dahlia.withdraw(marketId, shares, receiver, from);
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
        uint256 maxShares = _maxMint();
        maxAssets = SharesMathLib.toAssetsDown(maxShares, 0, 0);
    }

    /// @inheritdoc IWrappedVault
    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toSharesDown(assets, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxMint(address) external pure returns (uint256 maxShares) {
        maxShares = _maxMint();
    }

    function _maxMint() internal pure returns (uint256 maxShares) {
        maxShares = type(uint128).max;
    }

    /// @inheritdoc IWrappedVault
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toAssetsUp(shares, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxWithdraw(address addr) external view returns (uint256 maxAssets) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        uint256 maxAvailable = market.totalLendAssets - market.totalBorrowAssets;
        maxAssets = SoladyMath.min(maxAvailable, convertToAssets(balanceOf(addr)));
    }

    /// @inheritdoc IWrappedVault
    function previewWithdraw(uint256 assets) public view virtual returns (uint256 shares) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toSharesUp(assets, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function maxRedeem(address addr) external view returns (uint256 maxShares) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        uint256 maxAvailableAssets = market.totalLendAssets - market.totalBorrowAssets;
        uint256 maxAvailableShares = SharesMathLib.toSharesDown(maxAvailableAssets, market.totalLendAssets, market.totalLendShares);
        maxShares = SoladyMath.min(maxAvailableShares, balanceOf(addr));
    }

    /// @inheritdoc IWrappedVault
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        IDahlia.Market memory market = dahlia.getMarket(marketId);
        return SharesMathLib.toAssetsDown(shares, market.totalLendAssets, market.totalLendShares);
    }

    /// @inheritdoc IWrappedVault
    function owner() public view virtual override(IWrappedVault, Ownable) returns (address result) {
        return super.owner();
    }
}
