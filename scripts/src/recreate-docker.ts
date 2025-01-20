import { Command } from "commander";

import { addCommonOptions, interceptAllOutput, dockerOtterscan, allowedNetworks, Destination } from "./utils.ts";

await interceptAllOutput();

const program = new Command();
addCommonOptions(program);
program.parse(process.argv);

const options = program.opts<{ destination: Destination; network: string[] }>();

await dockerOtterscan({ script: "down-clean", network: allowedNetworks, destination: Destination.DOCKER });
await dockerOtterscan({ script: "up", ...options });
