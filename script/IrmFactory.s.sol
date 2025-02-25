// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IrmFactory } from "../src/irm/contracts/IrmFactory.sol";
import { BaseScript } from "./BaseScript.sol";

contract IrmFactoryScript is BaseScript {
    bytes32 private constant _SALT = keccak256(abi.encode("IrmFactory_V1"));

    function run() public {
        bytes memory initCode = type(IrmFactory).creationCode;
        string memory name = type(IrmFactory).name;
        _deploy(name, DEPLOYED_IRM_FACTORY, _SALT, initCode, true);
    }
}
