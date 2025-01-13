import { Command } from "commander";
import { execa } from "execa";
import fs from "fs";
import _ from "lodash";
import fsPromises from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import stripAnsi from "strip-ansi";

import { Config, configDeployedName, load, loadConfigFile, saveConfigFile } from "./config.ts";
import { waitForRpc } from "./waitForRpc.ts";

export enum Network {
  MAINNET = "mainnet",
  SEPOLIA = "sepolia",
  CARTIO = "cartio",
}
export const DEPLOY_NETWORKS: Network[] = [Network.CARTIO];

export interface Params {
  script: string;
  iterator?: string;
  remote?: boolean;
}

let isPatched = false;
async function interceptAllOutput(): Promise<void> {
  if (isPatched) return;
  isPatched = true;

  const program = new Command();
  program
    .option("-s, --script <path>", "Path to the .s.sol file", "")
    .option("-i, --iterator <name>", "Name of the iterator from config.yaml")
    .option("-r, --remote", "Deploy on remote", false)
    .parse(process.argv);
  const args = program.opts<Params>();

  const scriptName = path.basename(process.argv[1], path.extname(process.argv[1])); // e.g., "app"
  const currentUnixSeconds = Math.floor(Date.now() / 1000);

  const filePath = `./logs/${scriptName}-${args.script}-${currentUnixSeconds}.log`;
  if (fs.existsSync(filePath)) {
    await fsPromises.unlink(filePath);
  }
  await fsPromises.mkdir(path.dirname(filePath), { recursive: true });
  const logStream = fs.createWriteStream(filePath, { flags: "a" });

  // Save original write methods
  const originalStdoutWrite = process.stdout.write;
  const originalStderrWrite = process.stderr.write;

  const writeToLog = (chunk: any): void => {
    const message = typeof chunk === "string" ? chunk : chunk.toString();
    logStream.write(stripAnsi(message));
  };

  // Monkey-patch process.stdout.write
  process.stdout.write = function (chunk, encoding?: any, callback?: any) {
    writeToLog(chunk);
    return originalStdoutWrite.call(process.stdout, chunk, encoding, callback);
  };

  // Monkey-patch process.stderr.write
  process.stderr.write = function (chunk, encoding?: any, callback?: any) {
    writeToLog(chunk);
    return originalStderrWrite.call(process.stderr, chunk, encoding, callback);
  };
}

await interceptAllOutput();

const $$ = execa({ extendEnv: true, verbose: "full", stdout: ["pipe", "inherit"], stderr: ["pipe", "inherit"] });

export const recreateDockerOtterscan = async () => {
  await $$({ env: { NX_VERBOSE_LOGGING: "true", NO_COLORS: "true" } })`pnpm nx run dahlia:otterscan`;
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
  await $$`cast rpc --rpc-url ${rpcUrl} anvil_impersonateAccount ${ANVIL_ACCOUNT_ADDRESS}`;
  await $$`cast send --rpc-url ${rpcUrl} --from ${ANVIL_ACCOUNT_ADDRESS} ${address} --value ${amount} --unlocked`;
};

async function runScript(
  env: Readonly<Partial<Record<string, string>>>,
  creationScriptPath: string,
  cfg: Config,
  network: Network,
  deployedContracts: Config,
) {
  console.log("env", env);
  const { stdout } = await $$({
    env,
    cwd: "..",
  })`forge script script/${creationScriptPath} --rpc-url ${cfg.RPC_URL} --broadcast --private-key ${cfg.DAHLIA_PRIVATE_KEY}`;

  for (const line of stdout.split(/\r?\n/)) {
    const match = line.match(/^\s*(\S+)=(0x[a-fA-F0-9]+)\s+.*$/);
    if (match) {
      const [, name, address] = match;
      if (deployedContracts[network] === undefined) {
        deployedContracts[network] = {};
      }
      deployedContracts[network][name] = address;
    }
  }
}

export const deployContractsOnNetworks = async (params: Params): Promise<void> => {
  const deployedName = configDeployedName(params.remote);
  const deployedContracts = loadConfigFile(deployedName);
  for (const network of DEPLOY_NETWORKS) {
    const cfg: Config = load(network, deployedContracts[network]);
    if (params.remote) {
      if (!cfg.RPC_URL || !cfg.SCANNER_BASE_URL) {
        throw new Error("Missing RPC_URL or SCANNER_BASE_URL");
      }
    } else {
      if (!cfg.RPC_PORT || !cfg.OTT_PORT) {
        throw new Error("Missing RPC_PORT or OTT_PORT");
      }
      cfg.RPC_URL = `http://localhost:${cfg.RPC_PORT}`;
      const blockNumber = await waitForRpc(cfg.RPC_URL);
      cfg.SCANNER_BASE_URL = `http://localhost:${cfg.OTT_PORT}`;
      console.log(`Deploying contracts to rpcUrl=${cfg.RPC_URL}... blockNumber=${blockNumber}`);
    }

    const env = _.pickBy(cfg, (value) => typeof value === "string");

    if (params.iterator) {
      for (const [index, subvalue] of cfg[params.iterator].entries()) {
        const env = {
          ..._.pickBy(cfg, (value) => typeof value === "string"),
          ...subvalue,
          INDEX: index,
        };
        await runScript(env, params.script, cfg, network, deployedContracts);
      }
    } else {
      await runScript(env, params.script, cfg, network, deployedContracts);
    }
  }
  saveConfigFile(deployedName, deployedContracts);
};
