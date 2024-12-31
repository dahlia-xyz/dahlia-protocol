// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseScript } from "./BaseScript.sol";
import { console } from "@forge-std/console.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { DahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";

import { DahliaOracleFactory } from "src/oracles/contracts/DahliaOracleFactory.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { TestConstants } from "test/common/TestConstants.sol";

// Deploy contracts using CREATE2 contract (EVM Standard) for deterministic addresses
// Solidity CREATE2 implementation
// https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
// Foundry tutorial for self CREATE2
// https://book.getfoundry.sh/tutorials/create2-tutorial
// Foundry std function for computing CREATE2 address
// https://github.com/foundry-rs/forge-std/blob/f73c73d2018eb6a111f35e4dae7b4f27401e9421/src/StdUtils.sol#L122-L134
// Solana independent implementation
// https://github.com/Genesis3800/CREATE2Factory/blob/main/src/Create2.sol

string constant POINTS_FACTORY_SALT = "POINTS_FACTORY_V0.0.1";
string constant WRAPPED_VAULT_SALT = "WRAPPED_VAULT_V0.0.1";
string constant DAHLIA_REGISTRY_SALT = "DAHLIA_REGISTRY_V0.0.1";
string constant DAHLIA_SALT = "DAHLIA_V0.0.1";
string constant WRAPPED_VAULT_FACTORY_SALT = "WRAPPED_VAULT_FACTORY_V0.0.1";
string constant IRM_FACTORY_SALT = "IRM_FACTORY_V0.0.1";

// Kindof example https://github.com/0xsend/sendapp/blob/5fbf335a481d101d0ffd6649c2cfdc0bc1c20e16/packages/contracts/script/DeploySendAccountFactory.s.sol#L19

contract DeployDahlia is BaseScript {
    function _deployPointsFactory(address pointsFactoryEnvAddress, address daliaOwner) internal returns (address) {
        if (pointsFactoryEnvAddress != address(0)) {
            return pointsFactoryEnvAddress;
        } else {
            bytes32 salt = keccak256(abi.encode(POINTS_FACTORY_SALT));
            bytes memory encodedArgs = abi.encode(daliaOwner);
            bytes32 initCodeHash = hashInitCode(type(PointsFactory).creationCode, encodedArgs);
            address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
            if (expectedAddress.code.length > 0) {
                console.log("PointsFactory already deployed");
                return expectedAddress;
            } else {
                address pointsFactory = address(new PointsFactory{ salt: salt }(daliaOwner));
                require(expectedAddress == pointsFactory);
                return pointsFactory;
            }
        }
    }

    function _deployWrappedVault() internal returns (address) {
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_SALT));
        bytes32 initCodeHash = hashInitCode(type(WrappedVault).creationCode);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("WrappedVault already deployed");
            return expectedAddress;
        } else {
            address wrappedVault = address(new WrappedVault{ salt: salt }());
            require(expectedAddress == wrappedVault);
            return wrappedVault;
        }
    }

    function _deployDahliaRegistry(address dahliaOwner) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_REGISTRY_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner);
        bytes32 initCodeHash = hashInitCode(type(DahliaRegistry).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("DahliaRegistry already deployed");
            return expectedAddress;
        } else {
            address registry = address(new DahliaRegistry{ salt: salt }(dahliaOwner));
            require(expectedAddress == registry);
            return registry;
        }
    }

    function _deployDahlia(address dahliaOwner, address registry) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(DAHLIA_SALT));
        bytes memory encodedArgs = abi.encode(dahliaOwner, registry);
        bytes32 initCodeHash = hashInitCode(type(Dahlia).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("Dahlia already deployed");
            return expectedAddress;
        } else {
            address dahlia = address(new Dahlia{ salt: salt }(dahliaOwner, registry));
            require(expectedAddress == dahlia);
            return dahlia;
        }
    }

    function _deployWrappedVaultFactory(
        address wrappedVault,
        address feesRecipient,
        uint256 protocolFee,
        uint256 minimumFrontendFee,
        address dahliaOwner,
        address pointsFactory,
        address dahlia
    ) internal returns (address) {
        bytes32 salt = keccak256(abi.encode(WRAPPED_VAULT_FACTORY_SALT));
        bytes memory encodedArgs = abi.encode(wrappedVault, feesRecipient, protocolFee, minimumFrontendFee, dahliaOwner, pointsFactory, dahlia);
        bytes32 initCodeHash = hashInitCode(type(WrappedVaultFactory).creationCode, encodedArgs);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("WrappedVaultFactory already deployed");
            return expectedAddress;
        } else {
            address wrappedVaultFactory = address(
                new WrappedVaultFactory{ salt: salt }(
                    wrappedVault,
                    feesRecipient,
                    TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
                    TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
                    dahliaOwner,
                    pointsFactory,
                    dahlia
                )
            );
            require(expectedAddress == wrappedVaultFactory);
            return wrappedVaultFactory;
        }
    }

    function _deployIrmFactory() internal returns (IrmFactory) {
        bytes32 salt = keccak256(abi.encode(IRM_FACTORY_SALT));
        bytes32 initCodeHash = hashInitCode(type(IrmFactory).creationCode);
        address expectedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (expectedAddress.code.length > 0) {
            console.log("IrmFactory already deployed");
            return IrmFactory(expectedAddress);
        } else {
            IrmFactory irmFactory = new IrmFactory{ salt: salt }();
            address irmFactoryAddress = address(irmFactory);
            require(expectedAddress == irmFactoryAddress);
            return irmFactory;
        }
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

    function run() public {
        vm.startBroadcast(deployer);
        address dahliaOwner = vm.envAddress("DAHLIA_OWNER");
        address feesRecipient = vm.envAddress("FEES_RECIPIENT");
        console.log("Deployer address:", deployer);
        address pointsFactoryFromEnv = vm.envOr("POINTS_FACTORY", address(0));
        address pointsFactory = _deployPointsFactory(pointsFactoryFromEnv, dahliaOwner);
        _printContract("PointsFactory:              ", pointsFactory);
        address wrappedVault = _deployWrappedVault();
        _printContract("WrappedVault Implementation:", wrappedVault);
        address registry = _deployDahliaRegistry(dahliaOwner);
        _printContract("Registry:                   ", registry);
        // Deploy the contract
        address dahlia = _deployDahlia(dahliaOwner, registry);
        _printContract("Dahlia:                     ", dahlia);
        address wrappedVaultFactory = _deployWrappedVaultFactory(
            wrappedVault,
            feesRecipient,
            TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
            TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
            dahliaOwner,
            pointsFactory,
            dahlia
        );
        _printContract("WrappedVaultFactory:        ", wrappedVaultFactory);
        IrmFactory irmFactory = _deployIrmFactory();
        _printContract("IrmFactory:                ", address(irmFactory));

        uint64 ZERO_UTIL_RATE = 158_247_046;
        uint64 MIN_FULL_UTIL_RATE = 1_582_470_460;
        uint64 MAX_FULL_UTIL_RATE = 3_164_940_920_000;

        IIrm irm = irmFactory.createVariableIrm(
            VariableIrm.Config({
                minTargetUtilization: 75 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                maxTargetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                targetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                minFullUtilizationRate: MIN_FULL_UTIL_RATE,
                maxFullUtilizationRate: MAX_FULL_UTIL_RATE,
                zeroUtilizationRate: ZERO_UTIL_RATE,
                rateHalfLife: 172_800,
                targetRatePercent: 0.2e18
            })
        );
        _printContract("Irm:                        ", address(irm));

        address uniswapStaticOracleAddress = vm.envAddress("UNISWAP_STATIC_ORACLE_ADDRESS");
        address pythStaticOracleAddress = vm.envAddress("PYTH_STATIC_ORACLE_ADDRESS");

        DahliaOracleFactory oracleFactory = _deployDahliaOracleFactory(dahliaOwner, uniswapStaticOracleAddress, pythStaticOracleAddress);
        _printContract("DahliaOracleFactory:       ", address(oracleFactory));

        uint256 contractSize = dahlia.code.length;
        console.log("Dahlia contract size:", contractSize);
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("DAHLIA_PRIVATE_KEY"));
        DahliaRegistry(registry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, wrappedVaultFactory);
        vm.stopBroadcast();
    }
}
