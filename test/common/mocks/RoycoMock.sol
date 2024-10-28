// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PointsFactory} from "@royco/PointsFactory.sol";
import {WrappedVaultFactory} from "@royco/WrappedVaultFactory.sol";

import {IRoycoWrappedVaultFactory} from "src/core/interfaces/IRoycoWrappedVaultFactory.sol";
import {TestConstants} from "test/common/TestConstants.sol";

library RoycoMock {
    struct RoycoContracts {
        IRoycoWrappedVaultFactory erc4626iFactory;
        address pointsFactory;
    }

    function createRoycoContracts(address owner) public returns (RoycoContracts memory royco) {
        royco.pointsFactory = address(new PointsFactory(owner));
        royco.erc4626iFactory = IRoycoWrappedVaultFactory(
            address(
                new WrappedVaultFactory(
                    owner,
                    TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
                    TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
                    address(royco.pointsFactory)
                )
            )
        );
    }
}
