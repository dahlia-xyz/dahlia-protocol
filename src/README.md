# src

## Folder structure

```text
.
|-- core
|   |-- contracts
|   |   |-- Dahlia.sol
|   |   |   - The main contract of the Dahlia lending protocol
|   |   `-- DahliaRegistry.sol
|   |       - Registry for external addresses and global parameters
|   `-- (Purpose: Core contracts and interfaces for the Dahlia protocol)
|
|-- irm
|   |-- contracts
|   |   |-- IrmFactory.sol
|   |   |   - Factory contract used to create interest rate model (IRM) instances
|   |   `-- VariableIrm.sol
|   |       - Variable IRM contract used to compute and update interest rates
|   `-- (Purpose: Contracts related to the Interest Rate Model (IRM))
|
|-- oracles
|   |-- contracts
|   |   |-- ChainlinkWstETHToETH.sol
|   |   |   - Provides Chainlink compatible WSTETH-to-ETH price feed using Lido's WSTETH-STETH conversion rate and Chainlink STETH-to-ETH price feed
|   |   |-- DahliaChainlinkOracle.sol
|   |   |   - Dahlia Oracle leveraging Chainlink price feeds
|   |   |-- DahliaChainlinkOracleFactory.sol
|   |   |   - Factory to create and configure DahliaChainlinkOracle contracts
|   |   |-- DahliaDualOracle.sol
|   |   |   - Dahlia Oracle using multiple (dual) underlying Dahlia oracle sources
|   |   |-- DahliaDualOracleFactory.sol
|   |   |   - Factory to create and configure DahliaDualOracle contracts
|   |   |-- DahliaPythOracle.sol
|   |   |   - Dahlia Oracle leveraging Pyth price feeds
|   |   |-- DahliaPythOracleFactory.sol
|   |   |   - Factory to create and configure DahliaPythOracle contracts
|   |   |-- DahliaUniswapV3Oracle.sol
|   |   |   - Dahlia Oracle using Uniswap V3 price data
|   |   |-- DahliaUniswapV3OracleFactory.sol
|   |   |   - Factory to create and configure DahliaUniswapV3Oracle contracts
|   |   `-- Timelock.sol
|   |       - Timelock mechanism for delay parameter updates in oracles
|   `-- (Purpose: Contracts for interacting with external data feeds and price oracles)
|
`-- royco
    |-- contracts
    |   |-- WrappedVault.sol
    |   |   - Forked from `@royco/WrappedVault.sol` and modified for Dahlia lending support
    |   `-- WrappedVaultFactory.sol
    |       - Forked from `@royco/WrappedVaultFactory.sol` and modified for Dahlia lending support
    |-- interfaces
    |   `-- IDahliaWrappedVault.sol
    |       - Forked from `@royco/interfaces/IWrappedVault.sol` and extended
    |-- periphery
    |   `-- InitializableERC20.sol
    |       - Forked from `@royco/periphery/InitializableERC20.sol`
    `-- (Purpose: Royco contracts adapted for supporting Dahlia lending protocol)
```

## Design Highlights

- **WrappedVault.sol**
  - Preserves 100% ABI compatibility with the original Royco contract.
  - Retrieves its `balanceOf()` from the Dahlia protocol rather than storing share balances internally.
  - Uses the original principal assets for reward rate calculations.
  - Incorporates the Dahlia lending rate in the `previewRateAfterDeposit()` function.
- **WrappedVaultFactory.sol**
  - The `wrapVault()` function is restricted to be callable only by `Dahlia.sol`, diverging from Royco's original permissionless implementation of the `wrapVault()` function.
