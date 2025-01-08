import { execa } from "execa";
import process from "node:process";

import { DEPLOY_ON_REMOTE, envs, privateKey } from "./envs";
import { waitForRpc } from "./waitForRpc";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };

const $$ = execa({ verbose: "full" });

export const recreateDockerOtterscan = async () => await $$({ env })`pnpm nx run dahlia:otterscan`;

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

  await $$({
    cwd: "..",
    env: {
      ...clearPrefixOnEnvKeys(deploymentEnvs, network),
      SCANNER_BASE_URL: scannerBaseUrl,
    },
  })`forge script ${creationScriptPath} --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
};

export const deployContractsToMainnet = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
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

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, "MAINNET", envModifyCallback);
};

export const deployContractsToSepolia = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
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

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, "SEPOLIA", envModifyCallback);
};

export const deployContractsToCartio = async (
  creationScriptPath: string,
  envModifyCallback?: (envs: Record<string, string>) => Record<string, string>,
): Promise<void> => {
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

  await deployContracts(rpcUrl, scannerBaseUrl, creationScriptPath, "CARTIO", envModifyCallback);
};
