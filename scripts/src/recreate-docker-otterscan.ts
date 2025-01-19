import { Command } from "commander";

import {
  addCommonOptions,
  interceptAllOutput,
  dockerOtterscan,
  allowedNetworks,
  cleanOtterscanVolume,
  Destination,
} from "./utils.ts";

await interceptAllOutput();

const program = new Command();
addCommonOptions(program);
program.parse(process.argv);

const options = program.opts<{ destination: Destination; network: string[] }>();

await dockerOtterscan({ script: "down", network: allowedNetworks, destination: Destination.DOCKER });
await cleanOtterscanVolume();
await dockerOtterscan({ script: "up", ...options });
