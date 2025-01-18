import { Command } from "commander";

import { load } from "./config.ts";
import {
  addCommonOptions,
  interceptAllOutput,
  dockerOtterscan,
  allowedNetworks,
  cleanOtterscanVolume,
} from "./utils.ts";

await interceptAllOutput();

const program = new Command();
addCommonOptions(program);
program.parse(process.argv);

const options = program.opts<{ remote: boolean; network: string[] }>();

await dockerOtterscan({ script: "down", network: allowedNetworks, remote: false });
await cleanOtterscanVolume();
await dockerOtterscan({ script: "up", ...options });
