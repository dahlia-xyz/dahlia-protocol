# Dahlia

<!-- prettier-ignore-start -->

<!-- toc -->

+ [Tech Stack](#tech-stack)
+ [Setup](#setup)
+ [Run Tests](#run-tests)

<!-- tocstop -->

<!-- prettier-ignore-end -->

## Tech Stack

- [Foundry](https://book.getfoundry.sh/) - A smart contract development toolchain. Refer to [README.forge.md](README.forge.md) for more details.
- [Blockscout](https://github.com/blockscout/blockscout) - A blockchain explorer for the Hardhat node.
- [Otterscan](https://docs.otterscan.io/intro/what) - A blockchain explorer for Erigon and Anvil nodes.
- [Sourcify](https://sourcify.dev/) - A blockchain explorer for Erigon.

## Setup

To set up the development environment, follow these steps:

1. Install [foundry](https://book.getfoundry.sh/getting-started/installation#using-foundryup)
1. Ensure you have [pnpm](https://pnpm.io/) installed.
1. Run the setup command to prepare the environment:

```shell
pnpm run setup
```

## Run Tests

To execute tests, perform the following steps:

1. Duplicate the `.env.example` file and rename it to `.env`.
1. Configure the RPC endpoints in the `.env` file.
1. Execute the test command:

```shell
forge test
```
