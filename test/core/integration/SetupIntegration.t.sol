// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Dahlia} from "src/core/contracts/Dahlia.sol";
import {Errors} from "src/core/helpers/Errors.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {DahliaTransUtils} from "test/common/DahliaTransUtils.sol";
import {TestContext} from "test/common/TestContext.sol";

contract SetupIntegrationTest is Test {
    using BoundUtils for Vm;
    using DahliaTransUtils for Vm;

    TestContext ctx;

    function setUp() public {
        ctx = new TestContext(vm);
    }

    function test_int_setup_createDahlia_revert() public {
        address owner = ctx.createWallet("OWNER");
        vm.expectRevert(Errors.ZeroAddress.selector);
        new Dahlia(owner, address(0));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Dahlia(address(0), address(1));
    }
}
