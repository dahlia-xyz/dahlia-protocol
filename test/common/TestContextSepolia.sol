// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Vm } from "forge-std/Test.sol";
import { TestContextNetwork } from "test/common/TestContextNetwork.sol";

contract TestContextSepolia is TestContextNetwork {
    constructor(Vm vm_) TestContextNetwork(vm_) {
        vm.createSelectFork("sepolia");
        _addContract("USDC", 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8);
        _addContract("WBTC", 0xAe7C08f2FC56719b8F403C29F02E99CF809F8e34);
    }
}
