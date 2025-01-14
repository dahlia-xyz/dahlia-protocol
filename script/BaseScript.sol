// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;

import { Script } from "@forge-std/Script.sol";
import { console } from "@forge-std/console.sol";
import { LibString } from "@solady/utils/LibString.sol";

abstract contract BaseScript is Script {
    using LibString for *;

    string public constant DAHLIA_SALT = "DAHLIA_V0.0.1";

    address internal deployer;
    uint256 internal privateKey;
    uint256 internal blockNumber;
    string internal scannerBaseUrl;

    function setUp() public virtual {
        privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.rememberKey(privateKey);
        blockNumber = vm.getBlockNumber();
        scannerBaseUrl = vm.envString("SCANNER_BASE_URL");
        console.log("Deployer address:", deployer);
    }

    function _printContract(string memory name, address addr) internal {
        string memory host = string(abi.encodePacked(scannerBaseUrl, "/"));
        blockNumber++;
        string memory addressUrl = string(abi.encodePacked(host, "address/", (addr).toHexString()));
        string memory env = string(abi.encodePacked(name, "=", (addr).toHexString()));
        console.log(env, addressUrl);
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
