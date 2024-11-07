// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {UniswapV3SingleTwapBase} from "src/oracles/abstracts/UniswapV3SingleTwapBase.sol";
import {IDahliaOracle} from "src/oracles/interfaces/IDahliaOracle.sol";
import {IUniswapV3SingleTwapOracle} from "src/oracles/interfaces/IUniswapV3SingleTwapOracle.sol";

contract UniswapV3SingleTwap is UniswapV3SingleTwapBase, Ownable2Step, IDahliaOracle {
    constructor(address owner_, OracleParams memory params_, address uniswapStaticOracle_)
        UniswapV3SingleTwapBase(params_, uniswapStaticOracle_)
        Ownable(owner_)
    {}

    /// @inheritdoc IUniswapV3SingleTwapOracle
    function setTwapDuration(uint32 _newTwapDuration) external override onlyOwner {
        _setTwapDuration(_newTwapDuration);
    }

    /// @inheritdoc IDahliaOracle
    function getPrice() external view returns (uint256 price, bool isBadData) {
        price = _getUniswapV3Twap();
        isBadData = false;
    }
}
