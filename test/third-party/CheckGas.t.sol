// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {Dahlia} from "src/core/contracts/Dahlia.sol";
import {WrappedVaultFactory} from "src/royco/contracts/WrappedVaultFactory.sol";

contract CheckGas is Test {
    function test_3p_checkInitCodeSizeBatches() public pure {
        uint16 maxInitCodeSize = 40000; // TODO - disable in coverage and set to 24500

        console.log("Dahlia", type(Dahlia).creationCode.length);
        console.log("ERC4626Proxy", type(WrappedVaultFactory).creationCode.length);

        assertLe(type(Dahlia).creationCode.length, maxInitCodeSize, "Dahlia max init code size");
        assertLe(
            type(WrappedVaultFactory).creationCode.length, maxInitCodeSize, "WrappedVaultFactory max init code size"
        );
    }
}
