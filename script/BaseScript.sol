// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;

import { Script } from "../lib/forge-std/src/Script.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { ERC1967Proxy } from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CREATE3 } from "../lib/solady/src/utils/CREATE3.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";

abstract contract BaseScript is Script {
    using LibString for *;

    address internal deployer;
    string internal scannerBaseUrl;

    string internal constant DEPLOYED_REGISTRY = "DEPLOYED_REGISTRY";
    string internal constant DEPLOYED_DAHLIA = "DEPLOYED_DAHLIA";
    string internal constant DEPLOYED_PYTH_ADV_ORACLE_FACTORY = "DEPLOYED_PYTH_ADV_ORACLE_FACTORY";
    string internal constant DEPLOYED_PYTH_ORACLE_FACTORY = "DEPLOYED_PYTH_ORACLE_FACTORY";
    string internal constant DEPLOYED_PYTH_V2_ORACLE_FACTORY = "DEPLOYED_PYTH_V2_ORACLE_FACTORY";
    string internal constant DEPLOYED_CHAINLINK_ORACLE_FACTORY = "DEPLOYED_CHAINLINK_ORACLE_FACTORY";
    string internal constant DEPLOYED_WRAPPED_VAULT_FACTORY = "DEPLOYED_WRAPPED_VAULT_FACTORY";
    string internal constant DEPLOYED_WRAPPED_VAULT_IMPLEMENTATION = "DEPLOYED_WRAPPED_VAULT_IMPLEMENTATION";
    string internal constant DEPLOYED_IRM_FACTORY = "DEPLOYED_IRM_FACTORY";
    string internal constant DEPLOYED_TIMELOCK = "DEPLOYED_TIMELOCK";
    string internal constant DEPLOYED_CHAINLINK_WSTETH_ETH = "DEPLOYED_CHAINLINK_WSTETH_ETH";

    string internal constant DAHLIA_OWNER = "DAHLIA_OWNER";
    string internal constant INDEX = "INDEX";
    string internal constant DESTINATION = "DESTINATION";
    string internal constant POINTS_FACTORY = "POINTS_FACTORY";
    string internal constant TIMELOCK_DELAY = "TIMELOCK_DELAY";
    string internal constant PYTH_STATIC_ORACLE_ADDRESS = "PYTH_STATIC_ORACLE_ADDRESS";

    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        scannerBaseUrl = _envString("SCANNER_BASE_URL");
        console.log("Deployer address:", deployer);
    }

    function _printContract(string memory name, address addr, bool printBlock) internal view {
        string memory host = string(abi.encodePacked(scannerBaseUrl, "/"));
        string memory addressUrl = string(abi.encodePacked(host, "address/", (addr).toHexString()));
        string memory env = string(abi.encodePacked(name, "=", (addr).toHexString()));
        console.log(env, addressUrl);
        if (printBlock) {
            console.log(string(abi.encodePacked(name, "_BLOCK=", (block.number).toString())));
        }
    }

    function _printContractAlready(string memory name, string memory varName, address addr) internal view {
        console.log(name, "already deployed");
        _printContract(varName, addr, false);
    }

    function _create2(string memory name, string memory varName, bytes32 salt, bytes memory initCode, bool printBlock) private returns (address addr) {
        bytes32 codeHash = keccak256(initCode);
        addr = vm.computeCreate2Address(salt, codeHash);
        if (addr.code.length > 0) {
            _printContractAlready(name, varName, addr);
        } else {
            vm.startBroadcast(deployer);
            assembly {
                addr := create2(0, add(initCode, 0x20), mload(initCode), salt)
                if iszero(addr) { revert(0, 0) }
            }
            vm.stopBroadcast();
            _printContract(varName, addr, printBlock);
        }
    }

    function _create3(string memory name, string memory varName, bytes32 salt, bytes memory initCode, bool printBlock) private returns (address addr) {
        addr = CREATE3.predictDeterministicAddress(salt);
        if (addr.code.length > 0) {
            _printContractAlready(name, varName, addr);
        } else {
            vm.startBroadcast(deployer);
            addr = CREATE3.deployDeterministic(initCode, salt);
            vm.stopBroadcast();
            _printContract(varName, addr, printBlock);
        }
    }

    function _deploy(string memory name, string memory varName, bytes32 salt, bytes memory initCode, bool printBlock) internal returns (address addr) {
        addr = _envOr(varName, address(0));
        if (addr.code.length == 0 || addr == address(0)) {
            addr = _create2(name, varName, salt, initCode, printBlock);
        } else {
            console.log(name, "already deployed");
            _printContract(varName, addr, false);
        }
    }

    function _deployProxy(string memory name, string memory varName, bytes32 salt, bytes memory initCode, bool printBlock) internal returns (address addr) {
        addr = _envOr(varName, address(0));
        if (addr.code.length == 0 || addr == address(0)) {
            bytes memory proxyBytecode = abi.encodePacked(type(ERC1967Proxy).creationCode, initCode);
            addr = _create2(name, varName, salt, proxyBytecode, printBlock);
        } else {
            console.log(name, "already deployed");
            _printContract(varName, addr, false);
        }
    }

    function _envString(string memory name) internal view returns (string memory value) {
        value = vm.envString(name);
        console.log(string(abi.encodePacked(name, ": '", value, "'")));
    }

    function _envAddress(string memory name) internal view returns (address value) {
        value = vm.envAddress(name);
        console.log(string(abi.encodePacked(name, ": '", value.toHexString(), "'")));
    }

    function _envBytes32(string memory name) internal view returns (bytes32 value) {
        value = vm.envBytes32(name);
        console.log(string(abi.encodePacked(name, ": '", uint256(value).toHexString(), "'")));
    }

    function _envOr(string memory name, address defaultValue) internal view returns (address value) {
        value = vm.envOr(name, defaultValue);
        console.log(string(abi.encodePacked(name, ": '", value.toHexString(), "'")));
    }

    function _envUint(string memory name) internal view returns (uint256 value) {
        value = vm.envUint(name);
        console.log(string(abi.encodePacked(name, ": ", value.toString())));
    }

    function _envInt(string memory name) internal view returns (int256 value) {
        value = vm.envInt(name);
        console.log(string(abi.encodePacked(name, ": ", value.toString())));
    }

    function _envOr(string memory name, uint256 defaultValue) internal view returns (uint256 value) {
        value = vm.envOr(name, defaultValue);
        console.log(string(abi.encodePacked(name, ": '", value.toString(), "'")));
    }

    function _envOr(string memory name, bytes32 defaultValue) internal view returns (bytes32 value) {
        value = vm.envOr(name, defaultValue);
        console.log(string(abi.encodePacked(name, ": '", uint256(value).toHexString(), "'")));
    }
}
