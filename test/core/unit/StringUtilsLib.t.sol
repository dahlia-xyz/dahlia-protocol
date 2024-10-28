// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {StringUtilsLib} from "src/core/helpers/StringUtilsLib.sol";

contract StringUtilsLibTest is Test {
    function test_StringUtilsLib() public pure {
        assertEq(StringUtilsLib.toPercentString(100, 100), "100");
        assertEq(StringUtilsLib.toPercentString(8344, 10000), "83.44");
        assertEq(StringUtilsLib.toPercentString(83445, 100000), "83.44");
        assertEq(StringUtilsLib.toPercentString(81052, 100000), "81.05");
    }
}
