import { Command } from "commander";

import { deployContractsOnNetworks, Params } from "./utils.ts";

const program = new Command();

program
  .requiredOption("-s, --script <path>", "Path to the .s.sol file")
  .option("-r, --remote", "Deploy on remote", false)
  .parse(process.argv);

const options = program.opts<Params>();

await deployContractsOnNetworks(options);
