// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";

abstract contract MultipleSetupFunctions is Test {
    address public dualOracleAddress;

    function()[] internal setupFunctions;

    modifier useMultipleSetupFunctions() {
        for (uint256 i = 0; i < setupFunctions.length; i++) {
            setupFunctions[i]();
            _;
            vm.clearMockedCalls();
        }
    }
}
