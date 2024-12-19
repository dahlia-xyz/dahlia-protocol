# Dahlia

<!-- prettier-ignore-start -->

<!-- toc -->

+ [Tech Stack](#tech-stack)
+ [Setup](#setup)
+ [Run Tests](#run-tests)
  + [Test Private Metamask Account](#test-private-metamask-account)

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

### Test Private Metamask Account

For testing purposes, you can use the following private Metamask account:

- **Address:** 0x9AdA2DdDfd027689BFaa2fC8C8Eca56D2Ec18da9
- **Private Key:** 49c2a017327537646bccf0e4814624aa82d10595f79ea86793c5c242b4ee3891
