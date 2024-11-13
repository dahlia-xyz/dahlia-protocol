// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Owned } from "@solmate/auth/Owned.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { LibString } from "@solmate/utils/LibString.sol";
import { SharesMathLib } from "src/core/helpers/SharesMathLib.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

/// @title WrappedVaultFactory
/// @author CopyPaste, Jack Corddry, Shivaansh Kapoor
/// @dev A factory for deploying wrapped vaults, and managing protocol or other fees
contract WrappedVaultFactory is Owned {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _protocolFeeRecipient, uint256 _protocolFee, uint256 _minimumFrontendFee, address _owner, address _pointsFactory, address _dahlia)
        payable
        Owned(_owner)
    {
        if (_protocolFee > MAX_PROTOCOL_FEE) {
            revert ProtocolFeeTooHigh();
        }
        if (_minimumFrontendFee > MAX_MIN_REFERRAL_FEE) {
            revert ReferralFeeTooHigh();
        }

        protocolFeeRecipient = _protocolFeeRecipient;
        protocolFee = _protocolFee;
        minimumFrontendFee = _minimumFrontendFee;
        pointsFactory = _pointsFactory;
        dahlia = _dahlia;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_PROTOCOL_FEE = 0.3e18;
    uint256 public constant MAX_MIN_REFERRAL_FEE = 0.3e18;

    address public immutable pointsFactory;

    address public protocolFeeRecipient;

    /// @dev The protocolFee for all incentivized vaults
    uint256 public protocolFee;
    /// @dev The default minimumFrontendFee to initialize incentivized vaults with
    uint256 public minimumFrontendFee;

    /// @dev All incentivized vaults deployed by this factory
    address[] public incentivizedVaults;
    mapping(address => bool) public isVault;
    address public immutable dahlia;

    /*//////////////////////////////////////////////////////////////
                               INTERFACE
    //////////////////////////////////////////////////////////////*/
    error ProtocolFeeTooHigh();
    error ReferralFeeTooHigh();

    event ProtocolFeeUpdated(uint256 newProtocolFee);
    event ReferralFeeUpdated(uint256 newReferralFee);
    event ProtocolFeeRecipientUpdated(address newRecipient);
    event WrappedVaultCreated(
        ERC4626 indexed underlyingVaultAddress,
        WrappedVault indexed incentivizedVaultAddress,
        address owner,
        address inputToken,
        uint256 frontendFee,
        string name,
        string vaultSymbol
    );

    /*//////////////////////////////////////////////////////////////
                             OWNER CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @param newProtocolFee The new protocol fee to set for a given vault
    function updateProtocolFee(uint256 newProtocolFee) external payable onlyOwner {
        if (newProtocolFee > MAX_PROTOCOL_FEE) {
            revert ProtocolFeeTooHigh();
        }
        protocolFee = newProtocolFee;
        emit ProtocolFeeUpdated(newProtocolFee);
    }

    /// @param newMinimumReferralFee The new minimum referral fee to set for all incentivized vaults
    function updateMinimumReferralFee(uint256 newMinimumReferralFee) external payable onlyOwner {
        if (newMinimumReferralFee > MAX_MIN_REFERRAL_FEE) {
            revert ReferralFeeTooHigh();
        }
        minimumFrontendFee = newMinimumReferralFee;
        emit ReferralFeeUpdated(newMinimumReferralFee);
    }

    /// @param newRecipient The new protocol fee recipient to set for all incentivized vaults
    function updateProtocolFeeRecipient(address newRecipient) external payable onlyOwner {
        protocolFeeRecipient = newRecipient;
        emit ProtocolFeeRecipientUpdated(newRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                             VAULT CREATION
    //////////////////////////////////////////////////////////////*/

    /// @param marketId The market id in dahlia
    /// @param loanToken The address of the loan token
    /// @param owner The address of the wrapped vault owner
    /// @param name The name of the dahlia market
    /// @param initialFrontendFee The initial frontend fee for the wrapped vault ()
    function wrapVault(IDahlia.MarketId marketId, address loanToken, address owner, string calldata name, uint256 initialFrontendFee)
        external
        payable
        returns (WrappedVault wrappedVault)
    {
        string memory newSymbol = getNextSymbol();
        bytes32 salt = keccak256(abi.encodePacked(marketId, owner, name, initialFrontendFee));
        uint8 decimals = IERC20Metadata(loanToken).decimals() + SharesMathLib.VIRTUAL_SHARES_DECIMALS;
        wrappedVault = new WrappedVault{ salt: salt }(owner, name, newSymbol, dahlia, decimals, marketId, loanToken, initialFrontendFee, pointsFactory);

        incentivizedVaults.push(address(wrappedVault));
        isVault[address(wrappedVault)] = true;

        emit WrappedVaultCreated(ERC4626(address(wrappedVault)), wrappedVault, owner, address(wrappedVault.asset()), initialFrontendFee, name, newSymbol);
    }

    /// @dev Helper function to get the symbol for a new incentivized vault, ROY-0, ROY-1, etc.
    function getNextSymbol() internal view returns (string memory) {
        // TODO: decide if this should stay ROY or should be DHL ?
        return string.concat("ROY-", LibString.toString(incentivizedVaults.length));
    }
}
