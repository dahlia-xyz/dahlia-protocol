// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, Vm} from "@forge-std/Test.sol";
import {Ownable, UniswapOraclerParams, UniswapV3SingleTwap} from "src/oracles/contracts/UniswapV3SingleTwap.sol";
import {BoundUtils} from "test/common/BoundUtils.sol";
import {TestContext} from "test/common/TestContext.sol";
import {Mainnet} from "test/oracles/Constants.sol";

contract UniswapV3SingleTwapTest is Test {
    using BoundUtils for Vm;

    TestContext ctx;
    UniswapV3SingleTwap oracle;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_921_816);
        ctx = new TestContext(vm);
        address owner = ctx.createWallet("OWNER");

        oracle = new UniswapV3SingleTwap(
            owner,
            UniswapOraclerParams({
                baseToken: Mainnet.WETH_ERC20,
                quoteToken: Mainnet.UNI_ERC20,
                uniswapV3PairAddress: Mainnet.UNI_ETH_UNI_V3_POOL,
                twapDuration: 900
            }),
            Mainnet.UNISWAP_STATIC_ORACLE_ADDRESS
        );
    }

    function test_oracle_uniswap_success() public view {
        (uint256 _price, bool _isBadData) = oracle.getPrice();
        assertEq(_price, 342170188147668813010937084335830514402);
        assertEq(((_price * 1e18) / 1e18) / 1e36, 342); // 342 UNI per 1 ETH
        assertEq(_isBadData, false);
    }

    function test_oracle_uniswap_setTwapDurationNotOwner() public {
        address alice = ctx.createWallet("ALICE");
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(alice)));
        oracle.setTwapDuration(500);
        vm.stopPrank();
    }

    function test_oracle_uniswap_setTwapDurationOwner() public {
        address owner = ctx.createWallet("OWNER");
        vm.startPrank(owner);

        oracle.setTwapDuration(500);

        vm.stopPrank();

        assertEq(oracle.twapDuration(), 500);
    }
}
