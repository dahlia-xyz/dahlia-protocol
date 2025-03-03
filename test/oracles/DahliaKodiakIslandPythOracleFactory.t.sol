// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CREATE3 } from "@solady/utils/CREATE3.sol";
import { DahliaOracleFactoryBase } from "src/oracles/abstracts/DahliaOracleFactoryBase.sol";
import { DahliaOracleStaticAddress } from "src/oracles/abstracts/DahliaOracleStaticAddress.sol";

import { DahliaKodiakIslandPythOracle } from "src/oracles/contracts/DahliaKodiakIslandPythOracle.sol";
import { DahliaKodiakIslandPythOracleFactory } from "src/oracles/contracts/DahliaKodiakIslandPythOracleFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestContext } from "test/common/TestContext.sol";
import { Berachain } from "test/oracles/Constants.sol";

contract DahliaKodiakIslandPythOracleFactoryTest is Test {
    using BoundUtils for Vm;

    TestContext public ctx;
    DahliaKodiakIslandPythOracleFactory public oracleFactory;

    function setUp() public {
        vm.createSelectFork("berachain", 1_436_384);
        ctx = new TestContext(vm);
        oracleFactory = ctx.createKodiakIslandPythOracleFactory();
    }

    function test_KodiakIslandPythOracleFactory_zero_address() public {
        vm.expectRevert(DahliaOracleFactoryBase.ZeroTimelockAddress.selector);
        new DahliaKodiakIslandPythOracleFactory(address(0), Berachain.PYTH_STATIC_ORACLE_ADDRESS);
        vm.expectRevert(DahliaOracleStaticAddress.ZeroStaticOracleAddress.selector);
        new DahliaKodiakIslandPythOracleFactory(address(this), address(0));
    }

    function test_KodiakIslandPythOracleFactory_constructor() public {
        vm.expectEmit(true, true, true, true);
        emit DahliaOracleFactoryBase.TimelockAddressUpdated(address(this));

        vm.expectEmit(true, true, true, true);
        emit DahliaOracleStaticAddress.StaticOracleAddressUpdated(Berachain.PYTH_STATIC_ORACLE_ADDRESS);

        new DahliaKodiakIslandPythOracleFactory(address(this), Berachain.PYTH_STATIC_ORACLE_ADDRESS);
    }

    function test_oracleFactory_kodiak_island_pyth_wberaHoneyToWethWithBadDataFromPyth() public {
        vm.pauseGasMetering();

        address timelock = address(ctx.createTimelock());

        DahliaKodiakIslandPythOracle.Params memory params = DahliaKodiakIslandPythOracle.Params({
            kodiakIsland: Berachain.WBERA_HONEY_KODIAK_ISLAND,
            baseToken0Feed: 0x962088abcfdbdb6e30db2e340c8cf887d9efb311b1f2f17b155a63dbb6d40265, // BERA
            baseToken1Feed: 0xf67b033925d73d43ba4401e00308d9b0f26ab4fbd1250e8b5407b9eaade7e1f4, // HONEY
            quoteToken: Berachain.WETH_ERC20,
            quoteFeed: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
        });
        DahliaKodiakIslandPythOracle.Delays memory delays =
            DahliaKodiakIslandPythOracle.Delays({ baseToken0MaxDelay: 86_400, baseToken1MaxDelay: 86_400, quoteMaxDelay: 86_400 });

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(address(0), timelock);

        vm.expectEmit(true, true, true, true);
        emit DahliaOracleStaticAddress.StaticOracleAddressUpdated(Berachain.PYTH_STATIC_ORACLE_ADDRESS);

        vm.expectEmit(true, true, true, true);
        emit DahliaKodiakIslandPythOracle.ParamsUpdated(params);

        vm.expectEmit(true, true, true, true);
        emit DahliaKodiakIslandPythOracle.MaximumOracleDelaysUpdated(
            DahliaKodiakIslandPythOracle.Delays({ baseToken0MaxDelay: 0, baseToken1MaxDelay: 0, quoteMaxDelay: 0 }), delays
        );

        bytes memory encodedArgs = abi.encode(oracleFactory.timelockAddress(), params, delays, oracleFactory.STATIC_ORACLE_ADDRESS());
        bytes32 salt = keccak256(encodedArgs);
        address oracleAddress = CREATE3.predictDeterministicAddress(salt, address(oracleFactory));

        vm.expectEmit(true, true, true, true, address(oracleFactory));
        emit DahliaKodiakIslandPythOracleFactory.DahliaKodiakIslandPythOracleCreated(address(this), oracleAddress);

        vm.resumeGasMetering();
        DahliaKodiakIslandPythOracle oracle = DahliaKodiakIslandPythOracle(oracleFactory.createKodiakIslandPythOracle(params, delays));
        (uint256 price, bool isBadData) = oracle.getPrice();
        vm.pauseGasMetering();
        assertEq(oracle.ORACLE_PRECISION_TOKEN0(), 10 ** 36);
        assertEq(oracle.ORACLE_PRECISION_TOKEN1(), 10 ** 36);
        assertEq(oracle.KODIAK_ISLAND(), Berachain.WBERA_HONEY_KODIAK_ISLAND);
        assertEq(oracle.QUOTE_TOKEN(), Berachain.WETH_ERC20);
        assertEq(oracle.BASE_TOKEN0_FEED(), 0x962088abcfdbdb6e30db2e340c8cf887d9efb311b1f2f17b155a63dbb6d40265);
        assertEq(oracle.BASE_TOKEN1_FEED(), 0xf67b033925d73d43ba4401e00308d9b0f26ab4fbd1250e8b5407b9eaade7e1f4);
        assertEq(oracle.QUOTE_FEED(), 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace);
        assertEq(oracle.baseToken0MaxDelay(), 86_400);
        assertEq(oracle.baseToken1MaxDelay(), 86_400);
        assertEq(oracle.quoteMaxDelay(), 86_400);
        assertEq(oracle.STATIC_ORACLE_ADDRESS(), oracleFactory.STATIC_ORACLE_ADDRESS());
        // TODO
        assertEq(price, 2_295_212_787_654_355_649_510_749_137_872_409);
        // TODO
        //        assertEq(((price * 1e18) / 1e18) / 1e36, 349); // 349 UNI per 1 WETH
        assertEq(isBadData, false);

        address oracle2 = oracleFactory.createKodiakIslandPythOracle(params, delays);
        assertEq(address(oracle), address(oracle2), "should be the same address");
    }
}
