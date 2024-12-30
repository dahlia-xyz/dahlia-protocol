// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { PythOracleBase } from "../abstracts/PythOracleBase.sol";
import { IPythOracle } from "../interfaces/IPythOracle.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";

/// @title PythOracle
/// @notice A contract that extends PythOracleBase.sol with ownership and oracle functionality
contract PythOracle is PythOracleBase, Ownable2Step, IDahliaOracle {
    /// @notice Constructor to initialize the contract with owner and parameters
    /// @param owner_ The address of the contract owner
    /// @param params_ The parameters for the oracle
    constructor(address owner_, PythOracleParams memory params_, address _pythStaticOracleAddress)
        PythOracleBase(params_, _pythStaticOracleAddress)
        Ownable(owner_)
    { }

    /// @inheritdoc IPythOracle
    function setMaxPriceAge(uint256 _maxPriceAge) external override onlyOwner {
        _setMaxPriceAge(_maxPriceAge);
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256, bool) {
        return _getPythPrice();
    }
}
