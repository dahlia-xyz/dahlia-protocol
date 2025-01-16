import { Command } from "commander";

import { deployContractsOnNetworks } from "./utils.ts";

const program = new Command();

program.option("-r, --remote", "Deploy on remote", false).parse(process.argv);

const options = program.opts<{ remote: boolean }>();
const remote = options.remote;

await import("./recreate-docker-otterscan.ts");
await deployContractsOnNetworks({ script: "PointsFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "ChainlinkWstETHToETH.s.sol", remote });
await deployContractsOnNetworks({ script: "WrappedVaultImplementation.s.sol", remote });
await deployContractsOnNetworks({ script: "DahliaRegistry.s.sol", remote });
await deployContractsOnNetworks({ script: "IrmFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "VariableIrm.s.sol", remote });
await deployContractsOnNetworks({ script: "Dahlia.s.sol", remote });
await deployContractsOnNetworks({ script: "WrappedVaultFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "Timelock.s.sol", remote });
await deployContractsOnNetworks({ script: "DahliaPythOracleFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "DahliaPythOracle.s.sol", remote });
await deployContractsOnNetworks({ script: "WrappedVault.s.sol", remote });
await deployContractsOnNetworks({ script: "DahliaRegistryTransfer.s.sol", remote });
