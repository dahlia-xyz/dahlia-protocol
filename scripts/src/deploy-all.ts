import { Command } from "commander";

import { addCommonOptions, deployContractsOnNetworks, dockerOtterscan, interceptAllOutput, Network } from "./utils.ts";

await interceptAllOutput();

const program = new Command();
addCommonOptions(program);
program.parse(process.argv);

const options = program.opts<{ remote: boolean; network: Network[] }>();
const { remote, network } = options;

if (!remote) await dockerOtterscan({ script: "up", ...options });
if (!remote) await deployContractsOnNetworks({ script: "PointsFactory", ...options });
await deployContractsOnNetworks({ script: "ChainlinkWstETHToETH", ...options });
await deployContractsOnNetworks({ script: "WrappedVaultImplementation", ...options });
await deployContractsOnNetworks({ script: "DahliaRegistry", ...options });
await deployContractsOnNetworks({ script: "IrmFactory", ...options });
await deployContractsOnNetworks({ script: "VariableIrm", ...options });
await deployContractsOnNetworks({ script: "Dahlia", ...options });
await deployContractsOnNetworks({ script: "WrappedVaultFactory", ...options });
await deployContractsOnNetworks({ script: "Timelock", ...options });
await deployContractsOnNetworks({ script: "DahliaPythOracleFactory", ...options });
await deployContractsOnNetworks({ script: "DahliaPythOracle", ...options });
await deployContractsOnNetworks({ script: "WrappedVault", ...options });
await deployContractsOnNetworks({ script: "DahliaRegistryTransfer", ...options });
