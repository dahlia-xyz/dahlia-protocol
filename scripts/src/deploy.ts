import { Command } from "commander";

import { deployContractsOnNetworks } from "./utils.ts";

const program = new Command();

program
  .requiredOption("-s, --script <path>", "Path to the .s.sol file")
  .option("-i, --iterator <name>", "Name of the iterator from config.yaml")
  .parse(process.argv);

const options = program.opts();

await deployContractsOnNetworks(options.script, options.iterator);
