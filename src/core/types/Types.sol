// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IIrm} from "src/irm/interfaces/IIrm.sol";

library Types {
    type MarketId is uint32;

    enum MarketStatus {
        None,
        Active,
        Paused,
        Deprecated
    }

    struct RateRange {
        uint24 min;
        uint24 max;
    }

    struct Market {
        // --- 31 bytes
        MarketId id; // 4 bytes
        uint24 lltv; // 3 bytes
        uint24 rltv; // 3 bytes
        MarketStatus status; // 1 byte
        address loanToken; // 20 bytes
        // --- 32 bytes
        address collateralToken; // 20 bytes
        uint48 updatedAt; // 6 bytes // https://doc.confluxnetwork.org/docs/general/build/smart-contracts/gas-optimization/timestamps-and-blocknumbers#understanding-the-optimization
        uint24 protocolFeeRate; // 3 bytes // taken from interest
        uint24 reserveFeeRate; // 3 bytes // taken from interest
        // --- 31 bytes
        address oracle; // 20 bytes
        uint64 fullUtilizationRate; // 3 bytes
        uint64 ratePerSec; // 8 bytes // store refreshed rate per second
        // --- 26 bytes
        IIrm irm; // 20 bytes
        uint24 liquidationBonusRate; // 3 bytes
        uint24 reallocationBonusRate; // 3 bytes
        // --- 20 bytes
        IERC4626 marketProxy; // 20 bytes // TODO: should be IWrappedVault interface to include Owned
        address marketDeployer;
        // --- having all 256 bytes at the end make deployment size smaller
        uint256 totalLendAssets; // 32 bytes
        uint256 totalLendShares; // 32 bytes
        uint256 totalBorrowAssets; // 32 bytes
        uint256 totalBorrowShares; // 32 bytes
    }

    // TODO: move to IDahlia?
    struct MarketConfig {
        address loanToken;
        address collateralToken;
        // TODO: should be interface?
        address oracle;
        IIrm irm;
        uint256 lltv;
        uint256 rltv;
        uint256 liquidationBonusRate;
        /// @dev owner of the deployed market
        address owner;
    }

    struct MarketUserPosition {
        uint256 lendShares;
        uint256 lendAssets; // store user initial lend assets
        uint256 borrowShares;
        uint256 collateral;
    }

    struct MarketData {
        Market market;
        mapping(address => MarketUserPosition) userPositions;
    }
}
