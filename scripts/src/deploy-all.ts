import { Command } from "commander";

import { deployContractsOnNetworks } from "./utils.ts";

const program = new Command();

program.option("-r, --remote", "Deploy on remote", false).parse(process.argv);

const options = program.opts<{ remote: boolean }>();
const remote = options.remote;

await import("./recreate-docker-otterscan.ts");
await deployContractsOnNetworks({ script: "DeployIrmFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "CreateVariableIrm.s.sol", iterator: "VariableIRMs", remote });
await deployContractsOnNetworks({ script: "Dahlia.s.sol", remote });
await deployContractsOnNetworks({ script: "DeployTimelock.s.sol", remote });
await deployContractsOnNetworks({ script: "DeployDahliaPythOracleFactory.s.sol", remote });
await deployContractsOnNetworks({ script: "CreateDahliaPythOracle.s.sol", iterator: "PythOracles", remote });
await deployContractsOnNetworks({ script: "WrappedVault.s.sol", iterator: "WrappedVaults", remote });
