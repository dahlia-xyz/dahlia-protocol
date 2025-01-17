# src

## Folder structure

```text
|- core/ - Core contracts and interfaces for the Dahlia protocol.
|  `- contracts/
|     |- Dahlia.sol - the main contract of Dahlia Lending protocol
|     `- DahliaRegistry.sol - registry contract to keep external addresses and parameter
|- irm/ - Contracts related to the Interest Rate Model (IRM).
|  `- contracts/
|     |- IrmFactory.sol - Factory to create Irm contracts
|     `- VariableIrm.sol - Variable Irm Factory contract to compute interest
|- oracles/ - Contracts for interacting with external data feeds and oracles.
|  `- contracts/
|     |- ChainlinkWstETHToETH.sol - contract to provide WSTETH to ETH price feed
|     |- DahliaChainlinkOracle.sol - Dahlia oracle using Chainlink price feeds
|     |- DahliaChainlinkOracleFactory.sol - Factory to create DahliaChainlinkOracle
|     |- DahliaDualOracle.sol - Dahlia oracle using dual price Dahlia oracles
|     |- DahliaDualOracleFactory.sol - Factory to create DahliaDualOracle
|     |- DahliaPythOracle.sol - Dahlia oracle using Pyth price feeds
|     |- DahliaPythOracleFactory.sol - Factory to create DahliaPythOracle
|     |- DahliaUniswapV3Oracle.sol - Dahlia oracle using Uniswap V3 price feeds
|     |- DahliaUniswapV3OracleFactory.sol - Factory to create DahliaUniswapV3Oracle
|     `- Timelock.sol - Timelock contract to protect delay changes in oracles
`- royco/ - The copied royco contracts to add Dahlia lending protocol support.
   |- contracts
   |  |- WrappedVault.sol - copied from `@royco/WrappedVault.sol`
   |  `- WrappedVaultFactory.sol - copied from `@royco/WrappedVaultFactory.sol`
   |- interfaces/
   |  `- IDahliaWrappedVault.sol - extended interface from `@royco/interfaces/IWrappedVault.sol`
   `- periphery
      `- InitializableERC20.sol - copied from `@royco/periphery/InitializableERC20.sol`
```

## Design points

- Copies of Royco contracts contains the minimal changes to support Dahlia lending protocol.
  - WrappedVault.sol should be 100% ABI compatible with original Royco contract
  - WrappedVault.sol get balanceOf() from Dahlia and does not store shares balances
  - Reward rate calculation use original principal assets to compute rewards
  - previewRateAfterDeposit function adds lending rate from Dahlia
  - WrappedVaultFactory.sol - wrapVault() can be called only from Dahlia.sol and is not compatible with Royco wrapVault() function
- Dahlia contract and WrappedVaultFactory depends on each other. The circular dependency resolved using DahliaRegistry contract
