import { execa } from "execa";
import fsSync from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { DEPLOY_NETWORKS, DEPLOY_ON_REMOTE, envs, privateKey } from "./envs";
import Network from "./network";
import { waitForRpc } from "./waitForRpc";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };

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
  child.stdout.on("data", (chunk) => {
    process.stdout.write(chunk); // console
    logStream.write(chunk); // file
  });

  // 2) Send stderr to console + file in real time
  child.stderr.on("data", (chunk) => {
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
const sendMoneyToAddressOnAnvil = async (rpcUrl: string, address: string, amount: number) => {
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

export const sendMoneyToAddressOnAnvilMainnet = async (address: string, amount: number) => {
  const rpcUrl = `http://localhost:${process.env.MAINNET_RPC_PORT}`;
  await sendMoneyToAddressOnAnvil(rpcUrl, address, amount);
};

export const sendMoneyToAddressOnAnvilSepolia = async (address: string, amount: number) => {
  const rpcUrl = `http://localhost:${process.env.SEPOLIA_RPC_PORT}`;
  await sendMoneyToAddressOnAnvil(rpcUrl, address, amount);
};

export const sendMoneyToAddressOnAnvilCartio = async (address: string, amount: number) => {
  const rpcUrl = `http://localhost:${process.env.CARTIO_RPC_PORT}`;
  await sendMoneyToAddressOnAnvil(rpcUrl, address, amount);
};

/**
 * Clears network prefixes - example: MAINNET__POINTS_FACTORY -> POINTS_FACTORY
 * @param envs
 * @param keyPrefix - example: MAINNET
 */
export const clearPrefixOnEnvKeys = (envs: Record<string, string>, keyPrefix: string): Record<string, string> => {
  const prefix = `${keyPrefix}__`;
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(envs)) {
    if (key.includes(prefix)) {
      result[key.replace(prefix, "")] = value;
    } else {
      result[key] = value;
    }
  }
  return result;
};

export const deployContracts = async (
  rpcUrl: string,
  scannerBaseUrl: string,
  creationScriptPath: string,
  network: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);
  const blockNumber = await waitForRpc(rpcUrl);
  console.log("blockNumber=" + blockNumber);

  const deploymentEnvs = envModifyCallback ? envModifyCallback(envs) : envs;

  const child = $$({
    cwd: "..",
    env: {
      ...clearPrefixOnEnvKeys(deploymentEnvs, network),
      SCANNER_BASE_URL: scannerBaseUrl,
    },
    stdout: "pipe",
    stderr: "pipe",
  })`forge script ${creationScriptPath} --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
  writeOutputToConsoleAndFile(child);
  await child;
};

export const deployContractsToMainnet = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
  if (!DEPLOY_NETWORKS.includes(Network.MAINNET)) {
    return;
  }

  let rpcUrl;
  let scannerBaseUrl;

  if (DEPLOY_ON_REMOTE) {
    if (!process.env.MAINNET_RPC_URL || !process.env.MAINNET_SCANNER_BASE_URL) {
      throw new Error("Missing MAINNET_RPC_URL or MAINNET_SCANNER_BASE_URL");
    }
    rpcUrl = process.env.MAINNET_RPC_URL;
    scannerBaseUrl = process.env.MAINNET_SCANNER_BASE_URL;
  } else {
    if (!process.env.MAINNET_RPC_PORT || !process.env.MAINNET_OTT_PORT) {
      throw new Error("Missing MAINNET_RPC_PORT or MAINNET_OTT_PORT");
    }
    rpcUrl = `http://localhost:${process.env.MAINNET_RPC_PORT}`;
    scannerBaseUrl = `http://localhost:${process.env.MAINNET_OTT_PORT}`;
  }

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, Network.MAINNET, envModifyCallback);
};

export const deployContractsToSepolia = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
  if (!DEPLOY_NETWORKS.includes(Network.SEPOLIA)) {
    return;
  }

  let rpcUrl;
  let scannerBaseUrl;

  if (DEPLOY_ON_REMOTE) {
    if (!process.env.SEPOLIA_RPC_URL || !process.env.SEPOLIA_SCANNER_BASE_URL) {
      throw new Error("Missing SEPOLIA_RPC_URL or SEPOLIA_SCANNER_BASE_URL");
    }
    rpcUrl = process.env.SEPOLIA_RPC_URL;
    scannerBaseUrl = process.env.SEPOLIA_SCANNER_BASE_URL;
  } else {
    if (!process.env.SEPOLIA_RPC_PORT || !process.env.SEPOLIA_OTT_PORT) {
      throw new Error("Missing SEPOLIA_RPC_PORT or SEPOLIA_OTT_PORT");
    }
    rpcUrl = `http://localhost:${process.env.SEPOLIA_RPC_PORT}`;
    scannerBaseUrl = `http://localhost:${process.env.SEPOLIA_OTT_PORT}`;
  }

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, Network.SEPOLIA, envModifyCallback);
};

export const deployContractsToCartio = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
  if (!DEPLOY_NETWORKS.includes(Network.CARTIO)) {
    return;
  }

  let rpcUrl;
  let scannerBaseUrl;

  if (DEPLOY_ON_REMOTE) {
    if (!process.env.CARTIO_RPC_URL || !process.env.CARTIO_SCANNER_BASE_URL) {
      throw new Error("Missing CARTIO_RPC_URL or CARTIO_SCANNER_BASE_URL");
    }
    rpcUrl = process.env.CARTIO_RPC_URL;
    scannerBaseUrl = process.env.CARTIO_SCANNER_BASE_URL;
  } else {
    if (!process.env.CARTIO_RPC_PORT || !process.env.CARTIO_OTT_PORT) {
      throw new Error("Missing CARTIO_RPC_PORT or CARTIO_OTT_PORT");
    }
    rpcUrl = `http://localhost:${process.env.CARTIO_RPC_PORT}`;
    scannerBaseUrl = `http://localhost:${process.env.CARTIO_OTT_PORT}`;
  }

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, Network.CARTIO, envModifyCallback);
};
