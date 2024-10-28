// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MarketStorage} from "src/core/abstracts/MarketStorage.sol";
import {Permitted} from "src/core/abstracts/Permitted.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {Events} from "src/core/helpers/Events.sol";
import {BorrowImpl} from "src/core/impl/BorrowImpl.sol";
import {InterestImpl} from "src/core/impl/InterestImpl.sol";
import {LendImpl} from "src/core/impl/LendImpl.sol";
import {LiquidationImpl} from "src/core/impl/LiquidationImpl.sol";
import {ManageMarketImpl} from "src/core/impl/ManageMarketImpl.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {
    IDahliaFlashLoanCallback,
    IDahliaLendCallback,
    IDahliaRepayCallback,
    IDahliaSupplyCollateralCallback
} from "src/core/interfaces/IDahliaCallbacks.sol";
import {IDahliaProvider} from "src/core/interfaces/IDahliaProvider.sol";
import {IDahliaRegistry} from "src/core/interfaces/IDahliaRegistry.sol";
import {IERC4626ProxyFactory} from "src/core/interfaces/IERC4626ProxyFactory.sol";
import {Types} from "src/core/types/Types.sol";
//TODO: protect some methods by ReentrancyGuard
//import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Dahlia
/// @notice The Dahlia contract.
contract Dahlia is Permitted, MarketStorage, IDahlia {
    using SafeERC20 for IERC20;

    uint24 public minLltv = Constants.DEFAULT_MIN_LLTV_RANGE; // Initial min lltv // 3 bytes
    uint24 public maxLltv = Constants.DEFAULT_MAX_LLTV_RANGE; // Initial max lltv // 3 bytes
    uint32 internal marketSequence; // 4 bytes
    address public proxyFactory; // 20 bytes
    IDahliaRegistry public dahliaRegistry; // 20 bytes

    address public protocolFeeRecipient; // 20 bytes
    address public reserveFeeRecipient; // 20 bytes

    /// @dev the owner should be used by governance controller to control the call of each onlyOwner function
    constructor(address _owner, address addressRegistry) Ownable(_owner) {
        require(addressRegistry != address(0), Errors.ZeroAddress());
        dahliaRegistry = IDahliaRegistry(addressRegistry);
        protocolFeeRecipient = _owner;
    }

    /// @inheritdoc IDahlia
    function setLltvRange(uint256 minLltv_, uint256 maxLltv_) external onlyOwner {
        // percent should be always between 0 and 100% and min ltv should be <= max ltv
        require(
            minLltv_ > 0 && maxLltv_ < Constants.LLTV_100_PERCENT && minLltv_ <= maxLltv_,
            Errors.LltvRangeNotValid(minLltv_, maxLltv_)
        );
        minLltv = uint24(minLltv_);
        maxLltv = uint24(maxLltv_);

        emit Events.SetLLTVRange(minLltv_, maxLltv_);
    }

    /// @inheritdoc IDahlia
    function setProtocolFeeRate(Types.MarketId id, uint32 newFeeRate) external onlyOwner {
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        _validateMarket(market.status, false);
        _accrueMarketInterest(marketData.userPositions, market);

        ManageMarketImpl.setProtocolFeeRate(market, newFeeRate);
    }

    /// @inheritdoc IDahlia
    function setReserveFeeRate(Types.MarketId id, uint32 newFeeRate) external onlyOwner {
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
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
    function deployMarket(Types.MarketConfig memory marketConfig, bytes calldata data)
        external
        returns (Types.MarketId id)
    {
        require(dahliaRegistry.isIrmAllowed(marketConfig.irm), Errors.IrmNotAllowed());
        require(marketConfig.lltv >= minLltv && marketConfig.lltv <= maxLltv, Errors.LltvNotAllowed());
        require(marketConfig.rltv < marketConfig.lltv, Errors.RltvNotAllowed());

        id = Types.MarketId.wrap(++marketSequence);

        ManageMarketImpl.deployMarket(markets, id, marketConfig);
        Types.Market storage market = markets[id].market;
        IERC4626 marketProxy = IERC4626ProxyFactory(dahliaRegistry.getAddress(Constants.ADDRESS_ID_MARKET_PROXY))
            .deployProxy(marketConfig, id);

        address provider = dahliaRegistry.getAddress(Constants.ADDRESS_ID_DAHLIA_PROVIDER);
        if (provider != address(0)) {
            IDahliaProvider(provider).onMarketDeployed(id, marketProxy, msg.sender, data);
        }
        market.marketProxy = marketProxy;
    }

    /// @inheritdoc IDahlia
    function lend(Types.MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256 shares)
    {
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);
        _accrueMarketInterest(positions, market);

        // Set isPermitted permission for ERC4626Proxy if it sent transaction
        if (msg.sender == address(market.marketProxy)) {
            isPermitted[onBehalfOf][msg.sender] = true;
        }
        shares = LendImpl.internalLend(market, positions[onBehalfOf], assets, onBehalfOf);

        if (callbackData.length > 0 && address(msg.sender).code.length > 0) {
            IDahliaLendCallback(msg.sender).onDahliaLend(assets, callbackData);
        }

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdraw(Types.MarketId id, uint256 shares, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
        returns (uint256 assets)
    {
        require(receiver != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);

        assets = LendImpl.internalWithdraw(market, positions[onBehalfOf], shares, onBehalfOf, receiver);

        // remove isPermitted if user withdraw all money by proxy
        if (msg.sender == address(market.marketProxy) && positions[onBehalfOf].lendShares == 0) {
            isPermitted[onBehalfOf][msg.sender] = false;
        }

        IERC20(market.loanToken).safeTransfer(receiver, assets);
    }

    /// @inheritdoc IDahlia
    function borrow(Types.MarketId id, uint256 assets, uint256 shares, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
        returns (uint256, uint256)
    {
        require(receiver != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, true);
        _accrueMarketInterest(positions, market);

        (assets, shares) =
            BorrowImpl.internalBorrow(market, positions[onBehalfOf], assets, shares, onBehalfOf, receiver, 0);

        IERC20(market.loanToken).safeTransfer(receiver, assets);
        return (assets, shares);
    }

    /// @inheritdoc IDahlia
    function repay(Types.MarketId id, uint256 assets, uint256 shares, address onBehalfOf, bytes calldata callbackData)
        external
        returns (uint256, uint256)
    {
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
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
    function liquidate(Types.MarketId id, address borrower, bytes calldata callbackData)
        external
        returns (uint256, uint256, uint256)
    {
        require(borrower != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);

        return LiquidationImpl.internalLiquidate(
            market, positions[borrower], positions[reserveFeeRecipient], borrower, callbackData
        );
    }

    /// @inheritdoc IDahlia
    function reallocate(Types.MarketId marketId, Types.MarketId marketIdTo, address borrower)
        external
        returns (uint256, uint256, uint256, uint256)
    {
        Types.MarketData storage marketData = markets[marketId];
        Types.MarketData storage marketDataTo = markets[marketIdTo];

        Types.Market storage market = marketData.market;
        Types.Market storage marketTo = marketDataTo.market;
        require(
            market.oracle == marketTo.oracle && market.loanToken == marketTo.loanToken
                && market.collateralToken == marketTo.collateralToken && market.marketDeployer == marketTo.marketDeployer,
            Errors.MarketsDiffer()
        );

        require(market.rltv < marketTo.rltv, Errors.MarketReallocationLtvInsufficient());

        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        mapping(address => Types.MarketUserPosition) storage positionsTo = marketDataTo.userPositions;

        _validateMarket(market.status, true);
        _validateMarket(marketTo.status, true);

        _accrueMarketInterest(positions, market);
        _accrueMarketInterest(positionsTo, marketTo);

        return
            LiquidationImpl.internalReallocate(market, marketTo, positions[borrower], positionsTo[borrower], borrower);
    }

    /// @inheritdoc IDahlia
    function supplyCollateral(Types.MarketId id, uint256 assets, address onBehalfOf, bytes calldata callbackData)
        external
    {
        require(assets > 0, Errors.ZeroAssets());
        require(onBehalfOf != address(0), Errors.ZeroAddress());
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        _validateMarket(market.status, true);
        ///@dev not needed accrue interest here

        BorrowImpl.internalSupplyCollateral(market, marketData.userPositions[onBehalfOf], assets, onBehalfOf);

        if (callbackData.length > 0) {
            IDahliaSupplyCollateralCallback(msg.sender).onDahliaSupplyCollateral(assets, callbackData);
        }

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IDahlia
    function withdrawCollateral(Types.MarketId id, uint256 assets, address onBehalfOf, address receiver)
        external
        isSenderPermitted(onBehalfOf)
    {
        require(assets > 0, Errors.ZeroAssets());
        require(receiver != address(0), Errors.ZeroAddress());

        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;

        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);

        BorrowImpl.internalWithdrawCollateral(market, positions[onBehalfOf], assets, onBehalfOf, receiver);

        IERC20(market.collateralToken).safeTransfer(receiver, assets);
    }

    /// @inheritdoc IDahlia
    function flashLoan(address token, uint256 assets, bytes calldata callbackData) external {
        require(assets != 0, Errors.ZeroAssets());

        IERC20(token).safeTransfer(msg.sender, assets);

        IDahliaFlashLoanCallback(msg.sender).onDahliaFlashLoan(assets, callbackData);

        IERC20(token).safeTransferFrom(msg.sender, address(this), assets); // TODO: do we need fee?

        emit Events.DahliaFlashLoan(msg.sender, token, assets);
    }

    /// @inheritdoc IDahlia
    function accrueMarketInterest(Types.MarketId id) external {
        Types.MarketData storage marketData = markets[id];
        Types.Market storage market = marketData.market;
        mapping(address => Types.MarketUserPosition) storage positions = marketData.userPositions;
        _validateMarket(market.status, false);
        _accrueMarketInterest(positions, market);
    }

    function _accrueMarketInterest(
        mapping(address => Types.MarketUserPosition) storage positions,
        Types.Market storage market
    ) internal {
        InterestImpl.executeMarketAccrueInterest(
            market, positions[protocolFeeRecipient], positions[reserveFeeRecipient]
        );
    }
}
