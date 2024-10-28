// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {Events} from "src/core//helpers/Events.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {IPermitted} from "src/core/interfaces/IPermitted.sol";

abstract contract Permitted is IPermitted, EIP712, Nonces {
    mapping(address => mapping(address => bool)) public isPermitted;

    bytes32 private constant HASH =
        keccak256("Permit(address signer,address onBehalfOf,bool isPermitted,uint256 nonce,uint256 deadline)");

    function hashTypedData(Data memory data) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(HASH, data)));
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        return ("Dahlia", "1");
    }

    modifier isSenderPermitted(address onBehalfOf) {
        if (!_isSenderPermitted(onBehalfOf)) {
            revert Errors.NotPermitted();
        }
        _;
    }

    /// @inheritdoc IPermitted
    function updatePermission(address onBehalfOf, bool newIsPermitted) external {
        if (newIsPermitted == isPermitted[msg.sender][onBehalfOf]) {
            revert Errors.AlreadySet();
        }
        isPermitted[msg.sender][onBehalfOf] = newIsPermitted;

        emit Events.updatePermission(msg.sender, msg.sender, onBehalfOf, newIsPermitted);
    }

    /// @inheritdoc IPermitted
    function updatePermissionWithSig(Data memory data, bytes memory signature) external {
        require(block.timestamp <= data.deadline, Errors.SignatureExpired());
        bytes32 digest = hashTypedData(data);
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(data.signer == recoveredSigner, Errors.InvalidSignature());
        _useCheckedNonce(recoveredSigner, data.nonce);

        isPermitted[data.signer][data.onBehalfOf] = data.isPermitted;

        emit Events.updatePermission(msg.sender, recoveredSigner, data.onBehalfOf, data.isPermitted);
    }

    /// @dev Returns whether the sender is permitted to manage `onBehalfOf`'s positions.
    function _isSenderPermitted(address onBehalfOf) internal view returns (bool) {
        return msg.sender == onBehalfOf || isPermitted[onBehalfOf][msg.sender];
    }
}
