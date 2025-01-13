// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";

contract DeployIrmFactory is BaseScript {
    function _deployIrmFactory() internal returns (address) {
        bytes32 salt = keccak256(abi.encode(IRM_FACTORY_SALT));
        bytes32 initCodeHash = hashInitCode(type(IrmFactory).creationCode);
        address irmFactory = vm.computeCreate2Address(salt, initCodeHash);
        if (irmFactory.code.length > 0) {
            _printContract("IrmFactory already deployed:", address(irmFactory), "IRM_FACTORY");
        } else {
            address irmFactoryAddress = address(new IrmFactory{ salt: salt }());
            require(irmFactory == irmFactoryAddress, "Unexpected irmFactory address");
            _printContract("IrmFactory:                 ", address(irmFactory), "IRM_FACTORY");
        }
        return irmFactory;
    }

    function run() public {
        vm.startBroadcast(deployer);
        _deployIrmFactory();
        vm.stopBroadcast();
    }
}
