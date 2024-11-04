// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PointsFactory} from "@royco/PointsFactory.sol";
import {WrappedVaultFactory} from "src/royco/contracts/WrappedVaultFactory.sol";

import {TestConstants} from "test/common/TestConstants.sol";

library RoycoMock {
    struct RoycoContracts {
        WrappedVaultFactory erc4626iFactory;
        address pointsFactory;
    }

    function createRoycoContracts(address owner, address dahlia) public returns (RoycoContracts memory royco) {
        royco.pointsFactory = address(new PointsFactory(owner));
        royco.erc4626iFactory = WrappedVaultFactory(
            address(
                new WrappedVaultFactory(
                    owner,
                    TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
                    TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE,
                    owner,
                    address(royco.pointsFactory),
                    dahlia
                )
            )
        );
    }
}
