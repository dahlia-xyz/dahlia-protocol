// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";

contract IrmFactoryScript is BaseScript {
    string public constant IRM_FACTORY_SALT = "IrmFactory_V1";

    function run() public {
        bytes32 salt = keccak256(abi.encode(IRM_FACTORY_SALT));
        bytes memory initCode = type(IrmFactory).creationCode;
        string memory name = type(IrmFactory).name;
        deploy(name, DEPLOYED_IRM_FACTORY, salt, initCode);
    }
}
