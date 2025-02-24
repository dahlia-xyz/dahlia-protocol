// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Vm } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { TestContextNetwork } from "test/common/TestContextNetwork.sol";

interface IERC20Mint is IERC20 {
    function mint(address account, uint256 value) external returns (bool);
}

contract TestContextBerachain is TestContextNetwork {
    address public constant KODIAK_SWAP_ROUTER02 = 0xe301E48F77963D3F7DbD2a4796962Bd7f3867Fb4;
    address public constant OOGABOOGA_SWAP_ROUTER02 = 0xFd88aD4849BA0F729D6fF4bC27Ff948Ab1Ac3dE7;
    // https://berascan.com/accounts
    address public constant TOP_ETH_ACCOUNT = 0x7b36A317795f671fB54A5dF267ea8345c0c0F8D7;

    constructor(Vm vm_) TestContextNetwork(vm_) {
        vm.createSelectFork("berachain");
        // https://docs.berachain.com/developers/deployed-contracts#deployed-contract-addresses
        _addContract("USDC", 0x549943e04f40284185054145c6E4e9568C1D3241, 0x90bc07408f5b5eAc4dE38Af76EA6069e1fcEe363);
        _addContract("WBTC", 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c);
        // https://berascan.com/token/0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590
        _addContract("WETH", 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590, 0x003Ca23Fd5F0ca87D01F6eC6CD14A8AE60c2b97D);
        // https://berascan.com/token/0x6969696969696969696969696969696969696969#balances
        _addContract("WBERA", 0x6969696969696969696969696969696969696969, 0x4Be03f781C497A489E3cB0287833452cA9B9E80B);
        // https://berascan.com/token/0xEc901DA9c68E90798BbBb74c11406A32A70652C3#balances
        _addContract("STONE", 0xEc901DA9c68E90798BbBb74c11406A32A70652C3, 0x8382FBcEbef31dA752c72885A61d4416F342c6C8);
        _addContract("USDC.e", 0x549943e04f40284185054145c6E4e9568C1D3241, 0x90bc07408f5b5eAc4dE38Af76EA6069e1fcEe363);
        // https://berascan.com/token/0x211cc4dd073734da055fbf44a2b4667d5e5fe5d2#balances
        _addContract("sUSDe", 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2, 0xE254B56E24e8939FD513E2CDB060DeC96d9Ee26d);
    }
}
