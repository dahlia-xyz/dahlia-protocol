// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";
import { MarketStorage } from "src/core/abstracts/MarketStorage.sol";
import { Permitted } from "src/core/abstracts/Permitted.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { Errors } from "src/core/helpers/Errors.sol";
import { Events } from "src/core/helpers/Events.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { StringUtilsLib } from "src/core/helpers/StringUtilsLib.sol";
import { BorrowImpl } from "src/core/impl/BorrowImpl.sol";
import { InterestImpl } from "src/core/impl/InterestImpl.sol";
import { LendImpl } from "src/core/impl/LendImpl.sol";
import { LiquidationImpl } from "src/core/impl/LiquidationImpl.sol";
import { ManageMarketImpl } from "src/core/impl/ManageMarketImpl.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import {
    IDahliaFlashLoanCallback,
    IDahliaLendCallback,
    IDahliaLiquidateCallback,
    IDahliaRepayCallback,
    IDahliaSupplyCollateralCallback
} from "src/core/interfaces/IDahliaCallbacks.sol";
import { IDahliaRegistry } from "src/core/interfaces/IDahliaRegistry.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { IWrappedVault } from "src/royco/interfaces/IWrappedVault.sol";
//TODO: protect some methods by ReentrancyGuard
//import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Dahlia
/// @notice The Dahlia contract.
contract Dahlia is Permitted, MarketStorage, IDahlia {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using FixedPointMathLib for uint256;

    RateRange public lltvRange;
    RateRange public liquidationBonusRateRange;

    uint32 internal marketSequence; // 4 bytes
    address public proxyFactory; // 20 bytes
    IDahliaRegistry public dahliaRegistry; // 20 bytes

    address public protocolFeeRecipient; // 20 bytes
    address public reserveFeeRecipient; // 20 bytes
    uint24 public flashLoanFeeRate; // 3 bytes

    /// @dev the owner should be used by governance controller to control the call of each onlyOwner function
    constructor(address _owner, address addressRegistry) Ownable(_owner) {
        require(addressRegistry != address(0), Errors.ZeroAddress());
        dahliaRegistry = IDahliaRegistry(addressRegistry);
        protocolFeeRecipient = _owner;
        lltvRange = RateRange(Constants.DEFAULT_MIN_LLTV_RANGE, Constants.DEFAULT_MAX_LLTV_RANGE);
        liquidationBonusRateRange = RateRange(uint24(Constants.DEFAULT_MIN_LIQUIDATION_BONUS_RATE), uint24(Constants.DEFAULT_MAX_LIQUIDATION_BONUS_RATE));
    }

    /// @inheritdoc IDahlia
    function setLltvRange(RateRange memory range) external onlyOwner {
        // percent should be always between 0 and 100% and min ltv should be <= max ltv
        require(range.min > 0 && range.max < Constants.LLTV_100_PERCENT && range.min <= range.max, Errors.RangeNotValid(range.min, range.max));
        lltvRange = range;

        emit Events.SetLLTVRange(range.min, range.max);
    }

    /// @inheritdoc IDahlia
    function setLiquidationBonusRateRange(RateRange memory range) external onlyOwner {
        // percent should be always between 0 and 100% and range.min should be <= range.max
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
        _validateMarket(market.status, false);
        _accrueMarketInterest(marketData.userPositions, market);

        ManageMarketImpl.setProtocolFeeRate(market, newFeeRate);
    }

    /// @inheritdoc IDahlia
    function setReserveFeeRate(MarketId id, uint32 newFeeRate) external onlyOwner {
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarket(market.status, false);
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

    function _validateLiquidationBonusRate(uint256 liquidationBonusRate, uint256 lltv) internal view override {
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
            loanTokenSymbol,
            "/",
            IERC20Metadata(marketConfig.collateralToken).symbol(),
            " (",
            StringUtilsLib.toPercentString(marketConfig.lltv, Constants.LLTV_100_PERCENT),
            "% LLTV)"
        );
        uint256 fee = dahliaRegistry.getValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_MIN_INITIAL_FRONTEND_FEE);
        address owner = msg.sender;
        if (marketConfig.owner != address(0)) {
            owner = marketConfig.owner;
        }
        IWrappedVault wrappedVault = WrappedVaultFactory(dahliaRegistry.getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY)).wrapVault(
            id, marketConfig.loanToken, owner, name, fee
        );
        ManageMarketImpl.deployMarket(markets, id, marketConfig, wrappedVault);
    }

    /// @inheritdoc IDahlia
    function lend(MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData) external returns (uint256 shares) {
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);
        _accrueMarketInterest(positions, market);

        // Set isPermitted permission for ERC4626Proxy if it sent transaction
        if (msg.sender == address(market.vault)) {
            isPermitted[onBehalfOf][msg.sender] = true;
        }
        shares = LendImpl.internalLend(market, positions[onBehalfOf], assets, onBehalfOf);

        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaLendCallback(msg.sender).onDahliaLend(assets, callbackData);
        }

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdraw(MarketId id, uint256 shares, address onBehalfOf, address receiver) external isSenderPermitted(onBehalfOf) returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);
        MarketUserPosition storage userPosition = positions[onBehalfOf];

        assets = LendImpl.internalWithdraw(market, userPosition, shares, onBehalfOf, receiver);
        uint256 adjustedAssets = FixedPointMathLib.min(assets, userPosition.lendAssets);
        userPosition.lendAssets -= adjustedAssets;

        // remove isPermitted if user withdraw all money by proxy
        if (msg.sender == address(market.vault) && positions[onBehalfOf].lendShares == 0) {
            isPermitted[onBehalfOf][msg.sender] = false;
        }

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    function claimInterest(MarketId id, address onBehalfOf, address receiver) external isSenderPermitted(onBehalfOf) returns (uint256 assets) {
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);
        MarketUserPosition storage position = positions[onBehalfOf];
        uint256 totalLendAssets = market.totalLendAssets;
        uint256 totalLendShares = market.totalLendShares;
        uint256 lendShares = position.lendAssets.toSharesDown(totalLendAssets, totalLendShares);
        uint256 sharesInterest = position.lendShares - lendShares;

        assets = LendImpl.internalWithdraw(market, positions[onBehalfOf], sharesInterest, onBehalfOf, receiver);
        // remove isPermitted if user withdraw all money by proxy
        if (msg.sender == address(market.vault) && positions[onBehalfOf].lendShares == 0) {
            isPermitted[onBehalfOf][msg.sender] = false;
        }

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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);
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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);

        BorrowImpl.internalSupplyCollateral(market, positions[onBehalfOf], collateralAssets, onBehalfOf);

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), collateralAssets);

        (borrowedAssets, borrowedShares) = BorrowImpl.internalBorrow(market, positions[onBehalfOf], borrowAssets, 0, onBehalfOf, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, borrowedAssets);
        return (borrowedAssets, borrowedShares);
    }

    // @inheritdoc IDahlia
    function repayAndWithdraw(MarketId id, uint256 collateralAssets, uint256 repayAssets, uint256 repayShares, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
        returns (uint256 repaidAssets, uint256 repaidShares)
    {
        require(collateralAssets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);
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
        _validateMarket(market.status, false);
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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);

        (repaidAssets, repaidShares, seizedCollateral) =
            LiquidationImpl.internalLiquidate(market, positions[borrower], positions[reserveFeeRecipient], borrower);

        // transfer  collateral (seized) to liquidator wallet from Dahlia wallet
        IERC20(market.collateralToken).safeTransfer(msg.sender, seizedCollateral);

        // this callback is for smart contract to receive repaid amount before they approve in collateral token
        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaLiquidateCallback(msg.sender).onDahliaLiquidate(repaidAssets, callbackData);
        }

        // transfer (repaid) assets from liquidator wallet to Dahlia wallet
        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);
    }

    /// @inheritdoc IDahlia
    function supplyCollateral(MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData) external {
        require(assets > 0, Errors.ZeroAssets());
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        MarketData storage marketData = markets[id];
        Market storage market = marketData.market;
        _validateMarket(market.status, true);
        ///@dev not needed accrue interest here

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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;

        _validateMarket(market.status, false);
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
        mapping(address => MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);
    }

    function _accrueMarketInterest(mapping(address => MarketUserPosition) storage positions, Market storage market) internal {
        InterestImpl.executeMarketAccrueInterest(market, positions[protocolFeeRecipient], positions[reserveFeeRecipient]);
    }
}
