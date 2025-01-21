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
  ETHEREUM = "ethereum",
  SEPOLIA = "sepolia",
  CARTIO = "cartio",
}

export enum Destination {
  DOCKER = "docker",
  DEV = "dev",
  PROD = "prod",
}

export const allowedNetworks = Object.values(Network);

export interface Params {
  script: string;
  destination: Destination;
  network: string[];
}

export function addCommonOptions(program: Command) {
  program.option("-d, --destination <destination>", "Deploy on remote", [Destination.DOCKER]).option(
    "-n, --network <values>",
    `Specify networks (comma-separated). Allowed values: ${allowedNetworks.join(", ")}`,
    (value) => {
      // Split the input into an array
      const networks = value.split(",");
      // Validate each network
      for (const network of networks) {
        if (!allowedNetworks.includes(network as Network)) {
          throw new Error(`Invalid network: ${network}. Allowed values are: ${allowedNetworks.join(", ")}`);
        }
      }
      return networks;
    },
    [Network.ETHEREUM, Network.CARTIO],
  );
}
const DEFAULT_ANVIL_PRIVATE_KEY = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

export async function interceptAllOutput(): Promise<void> {
  const program = new Command();
  program.option("-s, --script <path>", "Path to the .s.sol file", "");
  addCommonOptions(program);
  program.parse(process.argv);
  const args = program.opts<Params>();

  if (_.isUndefined(process.env["PRIVATE_KEY"])) {
    if (args.destination == Destination.PROD) {
      throw Error("Missing required deployer PRIVATE_KEY environment variable");
    } else {
      process.env["PRIVATE_KEY"] = DEFAULT_ANVIL_PRIVATE_KEY;
    }
  }

  if (_.isUndefined(process.env["WALLET_ADDRESS"])) {
    if (args.destination == Destination.PROD) {
      throw Error("Missing required owner WALLET_ADDRESS environment variable to own all deployed contracts");
    } else {
      process.env["WALLET_ADDRESS"] = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
    }
  }

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

const $$ = execa({ extendEnv: true, verbose: "full", stdout: ["pipe", "inherit"], stderr: ["pipe", "inherit"] });

const runDockerCommand = async (env: Readonly<Partial<Record<string, string>>>, cwd: string, script: string) => {
  console.log("env=", env);
  if (script === "up") {
    await $$({ env, cwd })`docker compose up --build --remove-orphans -d`;
  } else if (script === "down") {
    await $$({ env, cwd })`docker compose down --remove-orphans`;
  } else if (script === "down-clean") {
    await $$({ env, cwd })`docker compose down --remove-orphans --volumes`;
  } else {
    throw new Error(`Unknown script: ${script}`);
  }
};

export const dockerOtterscan = async (params: Params) => {
  const env = { COMPOSE_PROJECT_NAME: "dahlia" };
  if (params.destination != Destination.DOCKER) return;
  await runDockerCommand(env, "./docker/dahlia/", params.script);
  const networkPromises = params.network.map(async (network) => {
    const cfg: Config = load(network, {});
    const networkEnv = _.pickBy(cfg, (value) => typeof value === "string");

    const otterscanConfig = {
      erigonURL: `http://localhost:${networkEnv.RPC_PORT}`, // Otterscan requires external port, not Docker one
      beaconAPI: "",
      assetsURLPrefix: "",
      experimental: "",
      branding: {
        siteName: `${network} ${networkEnv.SCANNER_BASE_URL}`,
        networkTitle: network,
      },
      sourcifySources: {
        ipfs: "https://ipfs.io/ipns/repo.sourcify.dev",
        central_server: "http://sourcify:5555/verify",
      },
    };

    networkEnv["NX_VERBOSE_LOGGING"] = "true";
    networkEnv["COMPOSE_PROJECT_NAME"] = `dahlia-${network}`;
    networkEnv["OTTERSCAN_CONFIG"] = JSON.stringify(otterscanConfig);

    await runDockerCommand(networkEnv, "./docker/dahlia-network/", params.script);
    console.log(`Otterscan running under http://localhost:${networkEnv.OTTERSCAN_PORT}`);
  });

  // Wait for all networks to complete
  await Promise.all(networkPromises);
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
  script: string,
  cfg: Config,
  network: string,
  deployedContracts: Config,
) {
  // console.log("env=", env);
  console.log(`network=${network}: Deploying contracts rpcUrl=${cfg.RPC_URL}`);
  const { stdout } = await $$({
    env,
    cwd: "..",
  })`forge script script/${script}.s.sol --rpc-url ${cfg.RPC_URL} --broadcast --private-key ${cfg.DEPLOYER_PRIVATE_KEY}`;

  for (const line of stdout.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z0-9_]+)=(0x[a-fA-F0-9]+|\d+)\b/);
    if (match) {
      const [, name, address] = match;
      if (deployedContracts[network] === undefined) {
        deployedContracts[network] = {};
      }
      deployedContracts[network][name] = address;
    }
  }
}

export const deployContractsOnNetworks = async (params: Params): Promise<Config> => {
  // Validate that --network is required if --remote is true
  if (params.destination != Destination.DOCKER && params.network.length > 1) {
    console.error("Error: Please specify --network when using --destination.");
    process.exit(1);
  }

  const deployedName = configDeployedName(params.destination);
  const deployedContracts = loadConfigFile(deployedName);
  for (const network of params.network) {
    const cfg: Config = load(network, deployedContracts[network]);
    if (params.destination == Destination.PROD) {
      if (!cfg.RPC_URL || !cfg.SCANNER_BASE_URL) {
        throw new Error("Missing RPC_URL or SCANNER_BASE_URL");
      }
    } else if (params.destination == Destination.DEV) {
      cfg.RPC_URL = `https://${network}-rpc.dahliadev.xyz`;
      cfg.SCANNER_BASE_URL = `https://${network}-otterscan.dahliadev.xyz`;
    } else {
      if (!cfg.RPC_PORT || !cfg.OTTERSCAN_PORT) {
        throw new Error("Missing RPC_PORT or OTTERSCAN_PORT");
      }
      cfg.RPC_URL = `http://localhost:${cfg.RPC_PORT}`;
      cfg.SCANNER_BASE_URL = `http://localhost:${cfg.OTTERSCAN_PORT}`;
    }
    deployedContracts[network]["CHAIN_ID"] = await waitForRpc(cfg.RPC_URL);
    deployedContracts[network]["GRAPH_NODE_RPC_PORT"] = cfg.GRAPH_NODE_RPC_PORT;
    //deployedContracts[network]["RPC_URL"] = cfg.RPC_URL;
    const scriptParam = cfg[params.script];
    // If is an Array iterate each value
    if (_.isArray(scriptParam)) {
      for (const [index, value] of cfg[params.script].entries()) {
        const env = {
          ..._.pickBy(cfg, (value) => typeof value === "string"),
          ...value,
          DESTINATION: params.destination.toString(),
          INDEX: index,
        };
        await runScript(env, params.script, cfg, network, deployedContracts);
      }
    } else if (_.isNull(scriptParam)) {
      // empty value
      const env = {
        ..._.pickBy(cfg, (value) => typeof value === "string"),
        DESTINATION: params.destination.toString(),
      };
      await runScript(env, params.script, cfg, network, deployedContracts);
    } else {
      console.log(`network=${network}: Skipped deployment of ${params.script}`);
    }
  }
  saveConfigFile(deployedName, deployedContracts);
  return deployedContracts;
};
