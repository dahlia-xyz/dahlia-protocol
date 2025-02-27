// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IIrm } from "../../irm/interfaces/IIrm.sol";
import { Constants } from "../helpers/Constants.sol";
import { Errors } from "../helpers/Errors.sol";
import { IDahliaRegistry } from "../interfaces/IDahliaRegistry.sol";

contract DahliaRegistry is IDahliaRegistry, Ownable {
    mapping(uint256 => address) internal addresses;
    mapping(uint256 => uint256) internal values;
    mapping(IIrm => bool) public isIrmAllowed;

    constructor(address _owner) Ownable(_owner) {
        _setValue(Constants.VALUE_ID_ROYCO_WRAPPED_VAULT_INITIAL_FRONTEND_FEE, Constants.ROYCO_WRAPPED_VAULT_INITIAL_FRONTEND_FEE);
        _setValue(Constants.VALUE_ID_DAHLIA_MARKET_INITIAL_PROTOCOL_FEE, Constants.DAHLIA_MARKET_INITIAL_PROTOCOL_FEE);
        _setValue(Constants.VALUE_ID_REPAY_PERIOD, Constants.REPAY_PERIOD);
    }

    /// @inheritdoc IDahliaRegistry
    function setAddress(uint256 id, address _addr) external onlyOwner {
        addresses[id] = _addr;
        emit SetAddress(id, _addr);
    }

    /// @inheritdoc IDahliaRegistry
    function getAddress(uint256 id) external view returns (address) {
        return addresses[id];
    }

    function _setValue(uint256 id, uint256 _val) internal {
        values[id] = _val;
        emit SetValue(id, _val);
    }

    /// @inheritdoc IDahliaRegistry
    function setValue(uint256 id, uint256 _val) external onlyOwner {
        _setValue(id, _val);
    }

    /// @inheritdoc IDahliaRegistry
    function getValue(uint256 id) external view returns (uint256) {
        return values[id];
    }

    /// @inheritdoc IDahliaRegistry
    function getValue(uint256 id, uint256 _def) external view returns (uint256) {
        if (values[id] == 0) {
            return _def;
        }
        return values[id];
    }

    /// @inheritdoc IDahliaRegistry
    function allowIrm(IIrm irm) external onlyOwner {
        require(!isIrmAllowed[irm], Errors.AlreadySet());
        isIrmAllowed[irm] = true;
        emit AllowIrm(irm);
    }

    /// @inheritdoc IDahliaRegistry
    function disallowIrm(IIrm irm) external onlyOwner {
        require(isIrmAllowed[irm], Errors.IrmNotAllowed());
        delete isIrmAllowed[irm];
        emit DisallowIrm(irm);
    }
}
