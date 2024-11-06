// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20, IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {SharesMathLib} from "src/core/helpers/SharesMathLib.sol";
import {StringUtilsLib} from "src/core/helpers/StringUtilsLib.sol";
import {IDahlia} from "src/core/interfaces/IDahlia.sol";
import {Types} from "src/core/types/Types.sol";

/// TODO: add comments
contract ERC4626Proxy is IERC4626, IERC20Permit, EIP712, Nonces {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;

    event ProxyDeposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event ProxyWithdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    bytes32 private constant HASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event ProxyApproval(address indexed owner, address indexed spender, uint256 value);

    error ERC4626ProxyMethodNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            ERC4626 STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 private immutable _asset;

    /*//////////////////////////////////////////////////////////////
                            DAHLIA STORAGE
    //////////////////////////////////////////////////////////////*/

    IDahlia public immutable dahlia;

    Types.MarketId public immutable marketId; // 4 bytes

    constructor(address dahlia_, Types.MarketConfig memory config, Types.MarketId id) {
        require(dahlia_ != address(0), Errors.ZeroAddress());
        dahlia = IDahlia(dahlia_);
        marketId = id;
        IERC20Metadata loanToken = IERC20Metadata(config.loanToken);
        string memory loanTokenSymbol = loanToken.symbol();
        name = string.concat(
            loanTokenSymbol,
            "/",
            IERC20Metadata(config.collateralToken).symbol(),
            " (",
            StringUtilsLib.toPercentString(config.lltv, Constants.LLTV_100_PERCENT),
            "% LLTV)"
        );

        decimals = loanToken.decimals();
        symbol = loanTokenSymbol;

        IERC20(config.loanToken).approve(dahlia_, type(uint256).max);

        _asset = IERC20(config.loanToken);
    }

    /**
     * @dev See {IERC4626-asset}.
     */
    function asset() external view returns (address) {
        return address(_asset);
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual returns (uint256) {
        (uint256 totalLendAssets,,,,,) = dahlia.getLastMarketState(marketId);
        return totalLendAssets;
    }

    /**
     * @dev See {IERC4626-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256 totalLendShares) {
        (, totalLendShares,,,,) = dahlia.getLastMarketState(marketId);
    }

    /**
     * @dev See {IERC4626-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256 lendShares) {
        return dahlia.getMarketUserPosition(marketId, account).lendShares;
    }

    /**
     * @dev See {IERC4626-convertToShares}.
     */
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return previewDeposit(assets);

        // (uint256 totalLendAssets, uint256 totalLendShares,,) = dahlia.getLastMarketState(marketConfig);
        // return SharesMathLib.toSharesDown(assets, totalLendAssets, totalLendShares);
    }

    /**
     * @dev See {IERC4626-convertToAssets}.
     */
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return previewRedeem(shares);
    }

    /**
     * @dev See {IERC4626-maxDeposit}.
     */
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev See {IERC4626-maxMint}.
     */
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev See {IERC4626-maxWithdraw}.
     */
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /**
     * @dev See {IERC4626-maxRedeem}.
     */
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        (uint256 totalLendAssets, uint256 totalLendShares,,,,) = dahlia.getLastMarketState(marketId);
        return SharesMathLib.toSharesDown(assets, totalLendAssets, totalLendShares);
    }
    /**
     * @dev See {IERC4626-previewMint}.
     */

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        (uint256 totalLendAssets, uint256 totalLendShares,,,,) = dahlia.getLastMarketState(marketId);
        return SharesMathLib.toAssetsUp(shares, totalLendAssets, totalLendShares);
    }

    /**
     * @dev See {IERC4626-previewWithdraw}.
     */
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        (uint256 totalLendAssets, uint256 totalLendShares,,,,) = dahlia.getLastMarketState(marketId);
        return SharesMathLib.toSharesUp(assets, totalLendAssets, totalLendShares);
    }

    /**
     * @dev See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        (uint256 totalLendAssets, uint256 totalLendShares,,,,) = dahlia.getLastMarketState(marketId);
        return SharesMathLib.toAssetsDown(shares, totalLendAssets, totalLendShares);
    }

    /**
     * @dev See {IERC4626-deposit}.
     */
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        return _deposit(msg.sender, receiver, assets);
    }

    // /**
    //  * @dev See {IERC4626-mint}.
    //  *
    //  * As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
    //  * In this case, the shares will be minted without requiring any assets to be deposited.
    //  */
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares);
        uint256 returnedShares;
        (returnedShares) = _deposit(msg.sender, receiver, assets);
        require(returnedShares == shares, "INCORRECT_SHARES_CALCULATION"); // TODO: remove this on release
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address caller, address receiver, uint256 assets) internal virtual returns (uint256 _shares) {
        _asset.safeTransferFrom(caller, address(this), assets);
        (_shares) = dahlia.lend(marketId, assets, receiver, bytes(""));

        emit ProxyDeposit(caller, receiver, assets, _shares);
    }

    /**
     * @dev See {IERC4626-withdraw}.
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 _shares) {
        _shares = previewWithdraw(assets);
        uint256 _assets = _withdraw(msg.sender, _shares, receiver, owner);
        require(assets == _assets, "INCORRECT_ASSETS_CALCULATION"); // TODO: remove this on release
    }

    /**
     * @dev See {IERC4626-redeem}.
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 _assets) {
        uint256 assets = previewRedeem(shares);
        (_assets) = _withdraw(msg.sender, shares, receiver, owner);
        require(assets == _assets, "INCORRECT_ASSETS_CALCULATION"); // TODO: remove this on release
    }

    function _withdraw(address caller, uint256 shares, address receiver, address owner)
        internal
        virtual
        returns (uint256 _assets)
    {
        if (caller != owner) {
            uint256 allowed = allowance[owner][caller]; // Saves gas for limited approvals.
            require(allowed >= shares, "NOT_ENOUGH_ALLOWANCE");
            if (allowed != type(uint256).max) {
                allowance[owner][caller] = allowed - shares;
            }
        }
        (_assets) = dahlia.withdraw(marketId, shares, owner, receiver);

        emit ProxyWithdraw(caller, receiver, owner, _assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert ERC4626ProxyMethodNotImplemented();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert ERC4626ProxyMethodNotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    (got from https://github.com/transmissions11/solmate/blob/34d20fc027fe8d50da71428687024a29dc01748b/src/tokens/ERC20.sol)
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
    {
        require(deadline >= block.timestamp, Errors.SignatureExpired());
        bytes32 digest = _hashTypedData(keccak256(abi.encode(HASH, owner, spender, value, _useNonce(owner), deadline)));
        address recoveredSigner = ECDSA.recover(digest, v, r, s);
        require(recoveredSigner == owner, Errors.InvalidSignature());
        allowance[recoveredSigner][spender] = value;
        emit ProxyApproval(owner, spender, value);
    }

    function _domainNameAndVersion() internal view override returns (string memory, string memory) {
        return (name, "1");
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    function nonces(address owner) public view virtual override (IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
