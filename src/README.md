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
|   |   |   - Provides Chainlink compatible WSTETH-to-ETH price feed using Chainlink STETH-to-ETH and Lido WSTETH-STETH
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
|   |       - Timelock mechanism for delayed parameter updates in oracles
|   `-- (Purpose: Contracts for interacting with external data feeds and oracles)
|
`-- royco
    |-- contracts
    |   |-- WrappedVault.sol
    |   |   - Copied from `@royco/WrappedVault.sol` with Dahlia lending support
    |   `-- WrappedVaultFactory.sol
    |       - Copied from `@royco/WrappedVaultFactory.sol` with Dahlia lending support
    |-- interfaces
    |   `-- IDahliaWrappedVault.sol
    |       - Extended from `@royco/interfaces/IWrappedVault.sol`
    |-- periphery
    |   `-- InitializableERC20.sol
    |       - Copied from `@royco/periphery/InitializableERC20.sol`
    `-- (Purpose: Royco contracts adapted to include Dahlia lending protocol support)
```

## Design points

- WrappedVault.sol
  - Preserves 100% ABI compatibility with the original Royco contract.
  - Retrieves its balanceOf() from the Dahlia protocol rather than storing share balances internally.
  - Uses the original principal assets for reward rate calculations.
  - Incorporates the Dahlia lending rate in the previewRateAfterDeposit() function.
- WrappedVaultFactory.sol
  - The wrapVault() function can be invoked only by Dahlia.sol, breaking compatibility with Royco's original wrapVault().
