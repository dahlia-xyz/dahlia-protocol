// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;

import { DahliaOracleFactory } from "../src/oracles/contracts/DahliaOracleFactory.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/Test.sol";

abstract contract BaseScript is Script {
    using LibString for *;

    string public constant DAHLIA_ORACLE_FACTORY_SALT = "DAHLIA_ORACLE_FACTORY_V0.0.1";

    address internal deployer;
    uint256 internal privateKey;
    uint256 internal blockNumber;
    string internal otterscanPort;

    function setUp() public virtual {
        privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.rememberKey(privateKey);
        blockNumber = vm.getBlockNumber();
        otterscanPort = vm.envOr("OTTERSCAN_PORT", string("80"));
    }

    function _printContract(string memory prefix, address addr) internal {
        string memory host = string(abi.encodePacked("http://localhost:", otterscanPort, "/"));
        blockNumber++;
        string memory blockUrl = string(abi.encodePacked(host, "block/", (blockNumber).toString()));
        string memory addressUrl = string(abi.encodePacked(host, "address/", (addr).toHexString()));
        console.log(prefix, addressUrl, blockUrl);
    }

    function _deployDahliaOracleFactory(address timelockAddress_, address uniswapStaticOracleAddress_, address pythStaticOracleAddress_)
        internal
        returns (DahliaOracleFactory)
    {
        // TODO: Maybe we need to pass uniswap address in the creation method? Since there is no such one on the cartio
        bytes32 salt = keccak256(abi.encode(DAHLIA_ORACLE_FACTORY_SALT));
        address expectedAddress = _calculateDahliaOracleFactoryExpectedAddress(timelockAddress_, uniswapStaticOracleAddress_, pythStaticOracleAddress_);
        if (expectedAddress.code.length > 0) {
            console.log("DahliaOracleFactory already deployed");
            return DahliaOracleFactory(expectedAddress);
        } else {
            DahliaOracleFactory oracleFactory = new DahliaOracleFactory{ salt: salt }(timelockAddress_, uniswapStaticOracleAddress_, pythStaticOracleAddress_);
            address oracleFactoryAddress = address(oracleFactory);
            require(expectedAddress == oracleFactoryAddress);
            return oracleFactory;
        }
    }

    function _calculateDahliaOracleFactoryExpectedAddress(address timelockAddress_, address uniswapStaticOracleAddress_, address pythStaticOracleAddress_)
        internal
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(DAHLIA_ORACLE_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(timelockAddress_, uniswapStaticOracleAddress_, pythStaticOracleAddress_);
        bytes32 initCodeHash = hashInitCode(type(DahliaOracleFactory).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        return expectedAddress;
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
