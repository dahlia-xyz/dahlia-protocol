// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Permitted } from "src/core/abstracts/Permitted.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
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

        emit Events.SetLLTVRange(range.min, range.max);
    }

    /// @inheritdoc IDahlia
    function setLiquidationBonusRateRange(RateRange memory range) external onlyOwner {
        // The percentage must always be between 0 and 100%, and range.min should be <= range.max.
        require(
            range.min >= Constants.DEFAULT_MIN_LIQUIDATION_BONUS_RATE && range.max <= Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE && range.min <= range.max,
            Errors.RangeNotValid(range.min, range.max)
        );
        liquidationBonusRateRange = range;

        emit Events.SetLiquidationBonusRateRange(range.min, range.max);
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
        emit Events.SetProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /// @inheritdoc IDahlia
    function setReserveFeeRecipient(address newReserveFeeRecipient) external onlyOwner {
        require(newReserveFeeRecipient != address(0), Errors.ZeroAddress());
        require(newReserveFeeRecipient != reserveFeeRecipient, Errors.AlreadySet());
        reserveFeeRecipient = newReserveFeeRecipient;
        emit Events.SetReserveFeeRecipient(newReserveFeeRecipient);
    }

    /// @inheritdoc IDahlia
    function setFlashLoanFeeRate(uint24 newFlashLoanFeeRate) external onlyOwner {
        require(newFlashLoanFeeRate <= Constants.MAX_FLASH_LOAN_FEE_RATE, Errors.MaxFeeExceeded());
        flashLoanFeeRate = uint24(newFlashLoanFeeRate);
        emit Events.SetFlashLoanFeeRate(newFlashLoanFeeRate);
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
        _validateLiquidationBonusRate(marketConfig.liquidationBonusRate, marketConfig.lltv);

        id = MarketId.wrap(++marketSequence);

        IERC20Metadata loanToken = IERC20Metadata(marketConfig.loanToken);
        string memory loanTokenSymbol = loanToken.symbol();
        string memory name = string.concat(
            loanTokenSymbol, "/", IERC20Metadata(marketConfig.collateralToken).symbol(), " (", MarketMath.toPercentString(marketConfig.lltv), "% LLTV)"
        );
        uint256 fee = dahliaRegistry.getValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_MIN_INITIAL_FRONTEND_FEE);
        address owner = marketConfig.owner == address(0) ? msg.sender : marketConfig.owner;
        IWrappedVault wrappedVault = WrappedVaultFactory(dahliaRegistry.getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY)).wrapVault(
            id, marketConfig.loanToken, owner, name, fee
        );
        ManageMarketImpl.deployMarket(markets, id, marketConfig, wrappedVault);
    }

    /// @inheritdoc IDahlia
    function lend(MarketId id, uint256 assets, address onBehalfOf) external returns (uint256 shares) {
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        _validateMarketActive(market.status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        shares = LendImpl.internalLend(market, positions[onBehalfOf], assets, onBehalfOf);

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdraw(MarketId id, uint256 shares, address onBehalfOf, address receiver) external payable nonReentrant returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
        MarketUserPosition storage userPosition = positions[onBehalfOf];

        assets = LendImpl.internalWithdraw(market, userPosition, shares, onBehalfOf, receiver);

        uint256 adjustedAssets = FixedPointMathLib.min(assets, userPosition.lendAssets);
        if (adjustedAssets != 0) {
            userPosition.lendAssets -= adjustedAssets.toUint128();
        }

        if (positions[onBehalfOf].lendShares == 0) {
            positions[onBehalfOf].lendAssets = 0; // write off single asset if 0 shares
        }

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    function claimInterest(MarketId id, address onBehalfOf, address receiver) external payable nonReentrant returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        IWrappedVault vault = market.vault;
        _permittedByWrappedVault(vault);
        // _validateMarketDeployed(market.status); no need to call because it's protected by _permittedByWrappedVault
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
        MarketUserPosition storage position = positions[onBehalfOf];

        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;
        uint256 lendShares = position.lendAssets.toSharesDown(totalLendAssets, totalLendShares);
        uint256 sharesInterest = position.lendShares - lendShares;

        assets = LendImpl.internalWithdraw(market, positions[onBehalfOf], sharesInterest, onBehalfOf, receiver);

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    function previewLendRateAfterDeposit(MarketId id, uint256 assets) external view returns (uint256) {
        Market memory market = InterestImpl.getLastMarketState(markets[id].market, assets);
        if (market.totalLendAssets == 0) {
            return 0;
        }
        return market.totalBorrowAssets.mulDiv(market.ratePerSec, market.totalLendAssets);
    }

    /// @inheritdoc IDahlia
    function borrow(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
        returns (uint256, uint256)
    {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        MarketStatus status = market.status;
        _validateMarketDeployedAndActive(status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        (assets, shares) = BorrowImpl.internalBorrow(market, positions[onBehalfOf], assets, shares, onBehalfOf, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, assets);
        return (assets, shares);
    }

    // @inheritdoc IDahlia
    function supplyAndBorrow(MarketId id, uint256 collateralAssets, uint256 borrowAssets, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
        returns (uint256 borrowedAssets, uint256 borrowedShares)
    {
        require(collateralAssets > 0 && borrowAssets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        BorrowImpl.internalSupplyCollateral(market, positions[onBehalfOf], collateralAssets, onBehalfOf);

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), collateralAssets);

        (borrowedAssets, borrowedShares) = BorrowImpl.internalBorrow(market, positions[onBehalfOf], borrowAssets, 0, onBehalfOf, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, borrowedAssets);
        return (borrowedAssets, borrowedShares);
    }

    // @inheritdoc IDahlia
    function repayAndWithdraw(MarketId id, uint256 collateralAssets, uint256 repayAssets, uint256 repayShares, address onBehalfOf, address receiver)
        external
        nonReentrant
        isSenderPermitted(onBehalfOf)
        returns (uint256 repaidAssets, uint256 repaidShares)
    {
        require(collateralAssets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        (repaidAssets, repaidShares) = BorrowImpl.internalRepay(market, positions[onBehalfOf], repayAssets, repayShares, onBehalfOf);
        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        BorrowImpl.internalWithdrawCollateral(market, positions[onBehalfOf], collateralAssets, onBehalfOf, receiver);
        IERC20(market.collateralToken).safeTransfer(receiver, collateralAssets);
    }

    /// @inheritdoc IDahlia
    function repay(MarketId id, uint256 assets, uint256 shares, address onBehalfOf, bytes calldata callbackData) external returns (uint256, uint256) {
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarketDeployed(market.status);
        _accrueMarketInterest(positions, market);

        (assets, shares) = BorrowImpl.internalRepay(market, positions[onBehalfOf], assets, shares, onBehalfOf);
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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
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
    function supplyCollateral(MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData) external {
        require(assets > 0, Errors.ZeroAssets());
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployedAndActive(market.status);
        /// @dev accrueInterest is not needed here.

        BorrowImpl.internalSupplyCollateral(market, marketData.userPositions[onBehalfOf], assets, onBehalfOf);

        if (callbackData.length > 0) {
            IDahliaSupplyCollateralCallback(msg.sender).onDahliaSupplyCollateral(assets, callbackData);
        }

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdrawCollateral(MarketId id, uint256 assets, address onBehalfOf, address receiver) external isSenderPermitted(onBehalfOf) {
        require(assets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());

        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);

        BorrowImpl.internalWithdrawCollateral(market, positions[onBehalfOf], assets, onBehalfOf, receiver);

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

        emit Events.DahliaFlashLoan(msg.sender, token, assets, fee);
    }

    /// @inheritdoc IDahlia
    function accrueMarketInterest(MarketId id) external {
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarketDeployed(market.status);
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _accrueMarketInterest(positions, market);
    }

    function _accrueMarketInterest(mapping(address => MarketUserPosition) storage positions, Market storage market) internal {
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
    function getMarketUserPosition(MarketId id, address userAddress) external view returns (MarketUserPosition memory) {
        return markets[id].userPositions[userAddress];
    }

    /// @inheritdoc IDahlia
    function marketUserMaxBorrows(MarketId id, address userAddress)
        external
        view
        returns (uint256 borrowAssets, uint256 maxBorrowAssets, uint256 collateralPrice)
    {
        MarketUserPosition memory position = markets[id].userPositions[userAddress];
        Market memory market = markets[id].market;
        collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        (borrowAssets, maxBorrowAssets) = MarketMath.calcMaxBorrowAssets(market, position, collateralPrice);
    }

    /// @inheritdoc IDahlia
    function getPositionLTV(MarketId id, address userAddress) external view returns (uint256 ltv) {
        MarketUserPosition memory position = markets[id].userPositions[userAddress];
        Market memory market = markets[id].market;
        uint256 collateralPrice = MarketMath.getCollateralPrice(market.oracle);
        return MarketMath.getLTV(market.totalBorrowAssets, market.totalBorrowShares, position, collateralPrice);
    }

    /// @inheritdoc IDahlia
    function getPositionInterest(MarketId id, address userAddress) external view returns (uint256 assets, uint256 shares) {
        MarketData storage marketData = markets[id];
        MarketUserPosition memory position = marketData.userPositions[userAddress];
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
        emit Events.MarketStatusChanged(market.status, MarketStatus.Paused);
        market.status = MarketStatus.Paused;
    }

    /// @inheritdoc IDahlia
    function unpauseMarket(MarketId id) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateMarketDeployed(market.status);
        require(market.status == MarketStatus.Paused, Errors.CannotChangeMarketStatus());
        emit Events.MarketStatusChanged(market.status, MarketStatus.Active);
        market.status = MarketStatus.Active;
    }

    /// @inheritdoc IDahlia
    function deprecateMarket(MarketId id) external onlyOwner {
        Market storage market = markets[id].market;
        _validateMarketDeployed(market.status);
        emit Events.MarketStatusChanged(market.status, MarketStatus.Deprecated);
        market.status = MarketStatus.Deprecated;
    }

    /// @inheritdoc IDahlia
    function updateLiquidationBonusRate(MarketId id, uint256 liquidationBonusRate) external {
        Market storage market = markets[id].market;
        _checkDahliaOwnerOrVaultOwner(market.vault);
        _validateLiquidationBonusRate(liquidationBonusRate, market.lltv);
        emit Events.LiquidationBonusRateChanged(liquidationBonusRate);
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
