import { Command } from "commander";
import { create } from "ipfs-http-client";

import {
  addCommonOptions,
  deployContractsOnNetworks,
  Destination,
  dockerOtterscan,
  interceptAllOutput,
  Network,
} from "./utils.ts";

await interceptAllOutput();

const program = new Command();
addCommonOptions(program);
program.parse(process.argv);

const options = program.opts<{ destination: Destination; network: Network[] }>();
const { destination, network } = options;

await dockerOtterscan({ script: "up", ...options });
if (destination === Destination.DOCKER) await deployContractsOnNetworks({ script: "PointsFactory", ...options });
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
const config = await deployContractsOnNetworks({ script: "DahliaRegistryTransfer", ...options });

const ipfs = create({ host: "localhost", port: 5001, protocol: "http" });
const { cid } = await ipfs.add(JSON.stringify(config));
console.log("Config File CID:", cid.toString());
