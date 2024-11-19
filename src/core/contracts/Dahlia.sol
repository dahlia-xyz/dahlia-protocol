// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Permitted } from "src/core/abstracts/Permitted.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { BorrowImpl } from "src/core/impl/BorrowImpl.sol";
import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { LendImpl } from "src/core/impl/LendImpl.sol";
import { LiquidationImpl } from "src/core/impl/LiquidationImpl.sol";
import { ManageMarketImpl } from "src/core/impl/ManageMarketImpl.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import {
    IDahliaFlashLoanCallback, IDahliaLiquidateCallback, IDahliaRepayCallback, IDahliaSupplyCollateralCallback
} from "src/core/interfaces/IDahliaCallbacks.sol";
import { IDahliaRegistry } from "src/core/interfaces/IDahliaRegistry.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";

/// @title Dahlia
/// @notice The Dahlia contract.
contract Dahlia is Permitted, Ownable2Step, IDahlia, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SharesMathLib for *;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    uint32 internal marketSequence; // 4 bytes
    IDahliaRegistry public dahliaRegistry; // 20 bytes
    RateRange public lltvRange; // 6 bytes
    RateRange public liquidationBonusRateRange; // 6 bytes

    address public protocolFeeRecipient; // 20 bytes
    address public reserveFeeRecipient; // 20 bytes
    uint24 public flashLoanFeeRate; // 3 bytes
    mapping(MarketId => MarketData) internal markets;

    /// @dev The owner is used by the governance controller to manage the execution of each `onlyOwner` function.
    constructor(address _owner, address addressRegistry) Ownable(_owner) {
        require(addressRegistry != address(0), Errors.ZeroAddress());
        dahliaRegistry = IDahliaRegistry(addressRegistry);
        protocolFeeRecipient = _owner;
        lltvRange = RateRange(Constants.DEFAULT_MIN_LLTV, Constants.DEFAULT_MAX_LLTV);
        liquidationBonusRateRange = RateRange(Constants.DEFAULT_MIN_LIQUIDATION_BONUS_RATE, Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE);
    }

    /// @inheritdoc IDahlia
    function setLltvRange(RateRange memory range) external onlyOwner {
        // The percentage must always be between 0 and 100%, and min LTV should be <= max LTV.
        require(range.min > 0 && range.max < Constants.LLTV_100_PERCENT && range.min <= range.max, Errors.RangeNotValid(range.min, range.max));
        lltvRange = range;

        emit SetLLTVRange(range.min, range.max);
    }

    /// @inheritdoc IDahlia
    function setLiquidationBonusRateRange(RateRange memory range) external onlyOwner {
        // The percentage must always be between 0 and 100%, and range.min should be <= range.max.
        require(
            range.min >= Constants.DEFAULT_MIN_LIQUIDATION_BONUS_RATE && range.max <= Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE && range.min <= range.max,
            Errors.RangeNotValid(range.min, range.max)
        );
        liquidationBonusRateRange = range;

        emit SetLiquidationBonusRateRange(range.min, range.max);
    }

    /// @inheritdoc IDahlia
    function setProtocolFeeRate(MarketId id, uint32 newFeeRate) external onlyOwner {
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        _accrueMarketInterest(marketData.userPositions, market);

        ManageMarketImpl.setProtocolFeeRate(market, newFeeRate);
    }

    /// @inheritdoc IDahlia
    function setReserveFeeRate(MarketId id, uint32 newFeeRate) external onlyOwner {
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        _accrueMarketInterest(marketData.userPositions, market);

        ManageMarketImpl.setReserveFeeRate(market, newFeeRate);
    }

    /// @inheritdoc IDahlia
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        require(newProtocolFeeRecipient != address(0), Errors.ZeroAddress());
        require(newProtocolFeeRecipient != protocolFeeRecipient, Errors.AlreadySet());
        protocolFeeRecipient = newProtocolFeeRecipient;
        emit SetProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /// @inheritdoc IDahlia
    function setReserveFeeRecipient(address newReserveFeeRecipient) external onlyOwner {
        require(newReserveFeeRecipient != address(0), Errors.ZeroAddress());
        require(newReserveFeeRecipient != reserveFeeRecipient, Errors.AlreadySet());
        reserveFeeRecipient = newReserveFeeRecipient;
        emit SetReserveFeeRecipient(newReserveFeeRecipient);
    }

    /// @inheritdoc IDahlia
    function setFlashLoanFeeRate(uint24 newFlashLoanFeeRate) external onlyOwner {
        require(newFlashLoanFeeRate <= Constants.MAX_FLASH_LOAN_FEE_RATE, Errors.MaxFeeExceeded());
        flashLoanFeeRate = uint24(newFlashLoanFeeRate);
        emit SetFlashLoanFeeRate(newFlashLoanFeeRate);
    }

    /// @notice Validates the liquidation bonus rate, ensuring it is within acceptable limits based on the market's LLTV.
    /// @param liquidationBonusRate The liquidation bonus rate to validate.
    /// @param lltv Liquidation loan-to-value for the market.
    function _validateLiquidationBonusRate(uint256 liquidationBonusRate, uint256 lltv) internal view {
        require(
            liquidationBonusRate >= liquidationBonusRateRange.min && liquidationBonusRate <= liquidationBonusRateRange.max
                && liquidationBonusRate <= MarketMath.getMaxLiquidationBonusRate(lltv),
            Errors.LiquidationBonusRateNotAllowed()
        );
    }

    /// @inheritdoc IDahlia
    function deployMarket(MarketConfig memory marketConfig) external returns (MarketId id) {
        require(dahliaRegistry.isIrmAllowed(marketConfig.irm), Errors.IrmNotAllowed());
        require(marketConfig.lltv >= lltvRange.min && marketConfig.lltv <= lltvRange.max, Errors.LltvNotAllowed());
        MarketMath.getCollateralPrice(marketConfig.oracle); // validate oracle
        _validateLiquidationBonusRate(marketConfig.liquidationBonusRate, marketConfig.lltv);

        id = MarketId.wrap(++marketSequence);

        uint256 fee = dahliaRegistry.getValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_MIN_INITIAL_FRONTEND_FEE);
        address owner = marketConfig.owner == address(0) ? msg.sender : marketConfig.owner;
        IWrappedVault wrappedVault = WrappedVaultFactory(dahliaRegistry.getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY)).wrapVault(
            id, marketConfig.loanToken, owner, marketConfig.name, fee
        );
        ManageMarketImpl.deployMarket(markets, id, marketConfig, wrappedVault);
    }

    /// @inheritdoc IDahlia
    function lend(MarketId id, uint256 assets, address owner) external returns (uint256 shares) {
        require(owner != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        _validateMarketActive(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        shares = LendImpl.internalLend(market, positions[owner], assets, owner);

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdraw(MarketId id, uint256 shares, address receiver, address owner) external payable nonReentrant returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
        UserPosition storage ownerPosition = positions[owner];

        assets = LendImpl.internalWithdraw(market, ownerPosition, shares, owner, receiver);

        uint256 userLendAssets = ownerPosition.lendAssets;
        uint256 adjustedAssets = FixedPointMathLib.min(assets, userLendAssets);
        uint256 resultingLendAssets = ownerPosition.lendShares == 0 ? 0 : userLendAssets - adjustedAssets;
        ownerPosition.lendAssets = resultingLendAssets.toUint128();

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    function claimInterest(MarketId id, address receiver, address owner) external payable nonReentrant returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
        UserPosition storage ownerPosition = positions[owner];

        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;
        uint256 lendShares = ownerPosition.lendAssets.toSharesDown(totalLendAssets, totalLendShares);
        uint256 sharesInterest = ownerPosition.lendShares - lendShares;

        assets = LendImpl.internalWithdraw(market, ownerPosition, sharesInterest, owner, receiver);

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    /// @param id The market id.
    /// @param lendAssets The amount of assets to deposit into the market.
    /// @return rate The expected rate after depositing `lendAssets` into the market.
    function previewLendRateAfterDeposit(MarketId id, uint256 lendAssets) external view returns (uint256 rate) {
        Market memory market = InterestImpl.getLastMarketState(markets[id].market, lendAssets);
        if (market.totalLendAssets != 0) return market.totalBorrowAssets.mulDiv(market.ratePerSec, market.totalLendAssets);
    }

    /// @inheritdoc IDahlia
    function borrow(MarketId id, uint256 assets, uint256 shares, address owner, address receiver)
        external
        isSenderPermitted(owner)
        returns (uint256, uint256)
    {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        MarketStatus status = market.status;
        _validateMarketDeployedAndActive(status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        (assets, shares) = BorrowImpl.internalBorrow(market, positions[owner], assets, shares, owner, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, assets);
        return (assets, shares);
    }

    // @inheritdoc IDahlia
    function supplyAndBorrow(MarketId id, uint256 collateralAssets, uint256 borrowAssets, address owner, address receiver)
        external
        isSenderPermitted(owner)
        returns (uint256 borrowedAssets, uint256 borrowedShares)
    {
        require(collateralAssets > 0 && borrowAssets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        UserPosition storage ownerPosition = positions[owner];
        BorrowImpl.internalSupplyCollateral(market, ownerPosition, collateralAssets, owner);

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), collateralAssets);

        (borrowedAssets, borrowedShares) = BorrowImpl.internalBorrow(market, ownerPosition, borrowAssets, 0, owner, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, borrowedAssets);
        return (borrowedAssets, borrowedShares);
    }

    // @inheritdoc IDahlia
    function repayAndWithdraw(MarketId id, uint256 collateralAssets, uint256 repayAssets, uint256 repayShares, address owner, address receiver)
        external
        nonReentrant
        isSenderPermitted(owner)
        returns (uint256 repaidAssets, uint256 repaidShares)
    {
        require(collateralAssets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
        UserPosition storage ownerPosition = positions[owner];
        (repaidAssets, repaidShares) = BorrowImpl.internalRepay(market, ownerPosition, repayAssets, repayShares, owner);
        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        BorrowImpl.internalWithdrawCollateral(market, ownerPosition, collateralAssets, owner, receiver);
        IERC20(market.collateralToken).safeTransfer(receiver, collateralAssets);
    }

    /// @inheritdoc IDahlia
    function repay(MarketId id, uint256 assets, uint256 shares, address owner, bytes calldata callbackData) external returns (uint256, uint256) {
        require(owner != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _validateMarketDeployed(market.status);
        _accrueMarketInterest(positions, market);

        (assets, shares) = BorrowImpl.internalRepay(market, positions[owner], assets, shares, owner);
        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaRepayCallback(msg.sender).onDahliaRepay(assets, callbackData);
        }

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), assets);
        return (assets, shares);
    }

    /// @inheritdoc IDahlia
    function liquidate(MarketId id, address borrower, bytes calldata callbackData)
        external
        returns (uint256 repaidAssets, uint256 repaidShares, uint256 seizedCollateral)
    {
        require(borrower != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        (repaidAssets, repaidShares, seizedCollateral) =
            LiquidationImpl.internalLiquidate(market, positions[borrower], positions[reserveFeeRecipient], borrower);

        // Transfer seized collateral from Dahlia to the liquidator's wallet.
        IERC20(market.collateralToken).safeTransfer(msg.sender, seizedCollateral);

        // This callback allows a smart contract to receive the repaid amount before approving in collateral token.
        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaLiquidateCallback(msg.sender).onDahliaLiquidate(repaidAssets, callbackData);
        }

        // Transfer repaid assets from the liquidator's wallet to Dahlia.
        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);
    }

    /// @inheritdoc IDahlia
    function supplyCollateral(MarketId id, uint256 assets, address owner, bytes calldata callbackData) external {
        require(assets > 0, Errors.ZeroAssets());
        require(owner != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        /// @dev accrueInterest is not needed here.

        BorrowImpl.internalSupplyCollateral(market, marketData.userPositions[owner], assets, owner);

        if (callbackData.length > 0) {
            IDahliaSupplyCollateralCallback(msg.sender).onDahliaSupplyCollateral(assets, callbackData);
        }

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdrawCollateral(MarketId id, uint256 assets, address owner, address receiver) external isSenderPermitted(owner) {
        require(assets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());

        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        BorrowImpl.internalWithdrawCollateral(market, positions[owner], assets, owner, receiver);

        IERC20(market.collateralToken).safeTransfer(receiver, assets);
    }

    /// @inheritdoc IDahlia
    function flashLoan(address token, uint256 assets, bytes calldata callbackData) external {
        require(assets != 0, Errors.ZeroAssets());

        uint256 fee = MarketMath.mulPercentUp(assets, flashLoanFeeRate);

        IERC20(token).safeTransfer(msg.sender, assets);

        IDahliaFlashLoanCallback(msg.sender).onDahliaFlashLoan(assets, fee, callbackData);

        IERC20(token).safeTransferFrom(msg.sender, address(this), assets);
        if (fee > 0) {
            IERC20(token).safeTransferFrom(msg.sender, protocolFeeRecipient, fee);
        }

        emit DahliaFlashLoan(msg.sender, token, assets, fee);
    }

    /// @inheritdoc IDahlia
    function accrueMarketInterest(MarketId id) external {
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        mapping(address => UserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
    }

    function _accrueMarketInterest(mapping(address => UserPosition) storage positions, Market storage market) internal {
        InterestImpl.executeMarketAccrueInterest(market, positions[protocolFeeRecipient], positions[reserveFeeRecipient]);
    }

    /// @notice Checks if the sender is the market or the wrapped vault owner.
    /// @param vault The wrapped vault associated with the market.
    function _checkDahliaOwnerOrVaultOwner(IWrappedVault vault) internal view {
        address sender = _msgSender();
        require(sender == owner() || sender == vault.vaultOwner(), Errors.NotPermitted(sender));
    }

    /// @inheritdoc IDahlia
    function getMarket(MarketId id) external view returns (Market memory) {
        return InterestImpl.getLastMarketState(markets[id].market, 0);
    }

    /// @inheritdoc IDahlia
    function getPosition(MarketId id, address userAddress) external view returns (UserPosition memory) {
        return markets[id].userPositions[userAddress];
    }

    /// @inheritdoc IDahlia
    function getMaxBorrowableAmount(MarketId id, address userAddress)
        external
        view
        returns (uint256 borrowAssets, uint256 maxBorrowAssets, uint256 collateralPrice)
    {
        MarketData storage marketData = markets[id];
        Market memory market = InterestImpl.getLastMarketState(marketData.market, 0);
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        UserPosition memory position = marketData.userPositions[userAddress];
        (borrowAssets, maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, collateralPrice);
    }

    /// @inheritdoc IDahlia
    function getPositionLTV(MarketId id, address userAddress) external view returns (uint256 ltv) {
        MarketData storage marketData = markets[id];
        Market memory market = InterestImpl.getLastMarketState(marketData.market, 0);
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        UserPosition memory position = marketData.userPositions[userAddress];
        return MarketMath.getLTV(market.totalBorrowAssets, market.totalBorrowShares, position, collateralPrice);
    }

    /// @inheritdoc IDahlia
    function getPositionInterest(MarketId id, address userAddress) external view returns (uint256 assets, uint256 shares) {
        MarketData storage marketData = markets[id];
        UserPosition memory position = marketData.userPositions[userAddress];
        Market memory state = InterestImpl.getLastMarketState(marketData.market, 0);
        uint256 lendShares = position.lendAssets.toSharesDown(state.totalLendAssets, state.totalLendShares);
        shares = position.lendShares - lendShares;
        assets = shares.toAssetsDown(state.totalLendAssets, state.totalLendShares);
    }

    /// @inheritdoc IDahlia
    function isMarketDeployed(MarketId id) external view virtual returns (bool) {
        return markets[id].market.status != MarketStatus.None;
    }

    /// @inheritdoc IDahlia
    function pauseMarket(MarketId id) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateMarketDeployed(market.status);
        require(market.status == MarketStatus.Active, Errors.CannotChangeMarketStatus());
        emit MarketStatusChanged(id, market.status, MarketStatus.Paused);
        market.status = MarketStatus.Paused;
    }

    /// @inheritdoc IDahlia
    function unpauseMarket(MarketId id) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateMarketDeployed(market.status);
        require(market.status == MarketStatus.Paused, Errors.CannotChangeMarketStatus());
        emit MarketStatusChanged(id, market.status, MarketStatus.Active);
        market.status = MarketStatus.Active;
    }

    /// @inheritdoc IDahlia
    function deprecateMarket(MarketId id) external onlyOwner {
        Market storage market = markets[id].market;
        _validateMarketDeployed(market.status);
        emit MarketStatusChanged(id, market.status, MarketStatus.Deprecated);
        market.status = MarketStatus.Deprecated;
    }

    /// @inheritdoc IDahlia
    function updateLiquidationBonusRate(MarketId id, uint256 liquidationBonusRate) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateLiquidationBonusRate(liquidationBonusRate, market.lltv);
        emit LiquidationBonusRateChanged(liquidationBonusRate);
        market.liquidationBonusRate = uint24(liquidationBonusRate);
    }

    /// @notice Validates the current market status is not None.
    /// @param status The current market status.
    function _validateMarketDeployed(MarketStatus status) internal pure {
        require(status != MarketStatus.None, Errors.MarketNotDeployed());
    }

    /// @notice Validates the current market status is paused or deprecated.
    /// @param status The current market status.
    function _validateMarketActive(MarketStatus status) internal pure {
        if (status == MarketStatus.Deprecated) {
            revert Errors.MarketDeprecated();
        } else if (status == MarketStatus.Paused) {
            revert Errors.MarketPaused();
        }
    }

    /// @notice Validates the current market status and market is paused or deprecated.
    /// @param status The current market status.
    function _validateMarketDeployedAndActive(MarketStatus status) internal pure {
        _validateMarketDeployed(status);
        _validateMarketActive(status);
    }

    /// @notice Validates if current sender is WrappedVault contract.
    /// @param vault WrappedVault contract address
    function _permittedByWrappedVault(IWrappedVault vault) internal view {
        require(msg.sender == address(vault), Errors.NotPermitted(msg.sender));
    }
}
