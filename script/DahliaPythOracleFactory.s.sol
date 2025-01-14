// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { DahliaPythOracleFactory } from "src/oracles/contracts/DahliaPythOracleFactory.sol";

contract DahliaPythOracleFactoryScript is BaseScript {
    function _deployDahliaPythOracleFactory(address timelockAddress, address pythStaticOracleAddress) internal returns (DahliaPythOracleFactory factory) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_PYTH_ORACLE_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(timelockAddress, pythStaticOracleAddress);
        bytes32 initCodeHash = hashInitCode(type(DahliaPythOracleFactory).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("DahliaOracleFactory already deployed");
            factory = DahliaPythOracleFactory(expectedAddress);
        } else {
            factory = new DahliaPythOracleFactory{ salt: salt }(timelockAddress, pythStaticOracleAddress);
        }
    }

    function run() public {
        vm.startBroadcast(deployer);
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK");
        DahliaPythOracleFactory oracleFactory = _deployDahliaPythOracleFactory(timelockAddress, pythStaticOracleAddress);
        _printContract("PYTH_ORACLE_FACTORY", address(oracleFactory));
        vm.stopBroadcast();
    }
}
