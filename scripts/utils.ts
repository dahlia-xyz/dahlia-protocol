import { execa } from "execa";
import _ from "lodash";
import fsSync from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { Config, load } from "./config.ts";
import { DEPLOY_NETWORKS, DEPLOY_ON_REMOTE } from "./envs.ts";
import { waitForRpc } from "./waitForRpc.ts";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true", NO_COLOR: "true", FORCE_COLOR: "false" };

// Get the name of the current script being executed
const scriptName = path.basename(process.argv[1], path.extname(process.argv[1])); // e.g., "app"
const currentUnixSeconds = Math.floor(Date.now() / 1000);

const filePath = `./logs/${scriptName}-${currentUnixSeconds}.log`;

// clear file before logging
if (fsSync.existsSync(filePath)) {
  await fs.unlink(filePath);
}

// create folder if it doesn't exist
await fs.mkdir(path.dirname(filePath), { recursive: true });

const writeOutputToConsoleAndFile = (child: any) => {
  const logStream = fsSync.createWriteStream(filePath, { flags: "a" });

  const cmdString =
    child.command ??
    [
      child.spawnfile,
      ...child.spawnargs.slice(1), // skip the first item since it's usually the same as child.spawnfile
    ].join(" ");

  logStream.write(`\n=== RUNNING COMMAND: ${cmdString} ===\n\n`);

  // 1) Send stdout to console + file in real time
  child.stdout.on("data", (chunk: string) => {
    process.stdout.write(chunk); // console
    logStream.write(chunk); // file
  });

  // 2) Send stderr to console + file in real time
  child.stderr.on("data", (chunk: string) => {
    process.stderr.write(chunk); // console
    logStream.write(chunk); // file
  });
};

const $$ = execa({ verbose: "full" });

export const recreateDockerOtterscan = async () => {
  const child = $$({ env })`pnpm nx run dahlia:otterscan`;
  writeOutputToConsoleAndFile(child);
  await child;
};

const ANVIL_ACCOUNT_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

/**
 * Sends money from first anvil hardcoded address with 10000 ETH to specified address
 * https://book.getfoundry.sh/tutorials/forking-mainnet-with-cast-anvil?highlight=anvil_impersonateAccount#transferring-dai
 * @param rpcUrl
 * @param address
 * @param amount
 */
export const sendMoneyToAddressOnAnvil = async (rpcUrl: string, address: string, amount: number) => {
  await waitForRpc(rpcUrl);
  // const last4DigitsOfReceiverAddress = address.slice(-4);
  // const logFilePath = `./logs/send-money-to-address-on-anvil-___${last4DigitsOfReceiverAddress}.log`;
  // const output = { file: logFilePath };
  const child = $$({
    env,
    stdout: "pipe",
    stderr: "pipe",
  })`cast rpc --rpc-url ${rpcUrl} anvil_impersonateAccount ${ANVIL_ACCOUNT_ADDRESS}`;
  writeOutputToConsoleAndFile(child);
  await child;
  const child2 = $$({
    env,
    stdout: "pipe",
    stderr: "pipe",
  })`cast send --rpc-url ${rpcUrl} --from ${ANVIL_ACCOUNT_ADDRESS} ${address} --value ${amount} --unlocked`;
  writeOutputToConsoleAndFile(child2);
  await child2;
};

async function runScript(env: Readonly<Partial<Record<string, string>>>, creationScriptPath: string, cfg: Config) {
  console.log("env", env);
  const child = $$({
    env,
    verbose: "full",
    cwd: "..",
    stdout: "pipe",
    stderr: "pipe",
  })`forge script ${creationScriptPath} --rpc-url ${cfg.RPC_URL} --broadcast --private-key ${cfg.DAHLIA_PRIVATE_KEY}`;
  writeOutputToConsoleAndFile(child);
  await child;
}

export const deployContractsOnNetworks = async (creationScriptPath: string, iter?: string): Promise<void> => {
  for (const network of DEPLOY_NETWORKS) {
    const cfg = load(network);
    if (DEPLOY_ON_REMOTE) {
      if (!cfg.RPC_URL || !cfg.SCANNER_BASE_URL) {
        throw new Error("Missing RPC_URL or SCANNER_BASE_URL");
      }
    } else {
      if (!cfg.RPC_PORT || !cfg.OTT_PORT) {
        throw new Error("Missing RPC_PORT or OTT_PORT");
      }
      cfg.RPC_URL = `http://localhost:${cfg.RPC_PORT}`;
      cfg.SCANNER_BASE_URL = `http://localhost:${cfg.OTT_PORT}`;
      console.log(`Deploying contracts to rpcUrl=${cfg.RPC_URL}...`);
      const blockNumber = await waitForRpc(cfg.RPC_URL);
      console.log("blockNumber=" + blockNumber);
    }

    const env = _.pickBy(cfg, (value) => typeof value === "string");

    if (iter) {
      for (const subvalue of cfg[iter]) {
        const env = {
          ..._.pickBy(cfg, (value) => typeof value === "string"),
          ...subvalue,
        };
        await runScript(env, creationScriptPath, cfg);
      }
    } else {
      await runScript(env, creationScriptPath, cfg);
    }
  }
};
