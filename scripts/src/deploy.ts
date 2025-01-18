import { Command } from "commander";

import { addCommonOptions, deployContractsOnNetworks, interceptAllOutput, Params } from "./utils.ts";

await interceptAllOutput();

const program = new Command();

program.requiredOption("-s, --script <path>", "Path to the .s.sol file");

addCommonOptions(program);

program.parse(process.argv);

const options = program.opts<Params>();

await deployContractsOnNetworks(options);
