// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;

import { LibString } from "@solady/utils/LibString.sol";
import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/Test.sol";

abstract contract BaseScript is Script {
    using LibString for *;

    address internal deployer;
    uint256 internal privateKey;

    function setUp() public virtual {
        privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.rememberKey(privateKey);
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    struct DeployReturn {
        address _address;
        bytes constructorParams;
        string contractName;
    }

    function _updateEnv(address, bytes memory, string memory) internal pure {
        console.log("_updateEnv is deprecated");
    }

    function deploy(function() returns (address, bytes memory, string memory) _deployFunction)
        internal
        broadcaster
        returns (address _address, bytes memory _constructorParams, string memory _contractName)
    {
        (_address, _constructorParams, _contractName) = _deployFunction();
        console.log("_constructorParams:");
        console.logBytes(_constructorParams);
        console.log(_contractName, "deployed to _address:", _address);
        _updateEnv(_address, _constructorParams, _contractName);
    }

    function deploy(function() returns (DeployReturn memory) _deployFunction) internal broadcaster returns (DeployReturn memory _return) {
        _return = _deployFunction();
    }
}
