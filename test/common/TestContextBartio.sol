// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Vm } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { TestContextNetwork } from "test/common/TestContextNetwork.sol";

interface IERC20Mint is IERC20 {
    function mint(address account, uint256 value) external returns (bool);
}

contract TestContextBartio is TestContextNetwork {
    constructor(Vm vm_) TestContextNetwork(vm_) {
        vm.createSelectFork("bartio");
        // https://bartio.beratrail.io/tokens
        _addContract("USDC", 0xd6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c);
        _addContract("WBTC", 0x2577D24a26f8FA19c1058a8b0106E2c7303454a4);
        // we get big supply address https://bartio.beratrail.io/token/0xE28AfD8c634946833e89ee3F122C06d7C537E8A8/balances
        _addContract("WETH", 0xE28AfD8c634946833e89ee3F122C06d7C537E8A8, 0xDa9487a32DD76e22B31cd5993F0699C0dc94435e);
        //        _addContract("WBERA", 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8); // can not be minted
        _addContract("STONE", 0xA4700DFb69C5D717Cd08e5dcCa4d319F07c049Af);
    }
}
