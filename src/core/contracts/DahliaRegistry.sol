// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Constants} from "src/core/helpers/Constants.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {IDahliaRegistry} from "src/core/interfaces/IDahliaRegistry.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";

contract DahliaRegistry is IDahliaRegistry, Ownable {
    mapping(uint256 => address) internal addresses;
    mapping(uint256 => uint256) internal values;
    mapping(IIrm => bool) public isIrmAllowed;

    constructor(address _owner) Ownable(_owner) {
        values[Constants.VALUE_ID_ROYCO_ERC4626I_FACTORY_MIN_INITIAL_FRONTEND_FEE] = 0.02e18;
    }

    /// @inheritdoc IDahliaRegistry
    function setAddress(uint256 id, address _addr) external onlyOwner {
        addresses[id] = _addr;
        emit SetAddress(msg.sender, id, _addr);
    }

    /// @inheritdoc IDahliaRegistry
    function getAddress(uint256 id) external view returns (address) {
        return addresses[id];
    }

    /// @inheritdoc IDahliaRegistry
    function setValue(uint256 id, uint256 _val) external onlyOwner {
        emit SetValue(msg.sender, id, _val);
        values[id] = _val;
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
        if (isIrmAllowed[irm]) {
            revert Errors.AlreadySet();
        }
        isIrmAllowed[irm] = true;
        emit IDahliaRegistry.AllowIrm(irm);
    }
}
