import { execa } from "execa";
import * as process from "node:process";

import { envs, privateKey } from "./consts";
import { waitForRpc } from "./waitForRpc";

const $$ = execa({ verbose: "full" });

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };
await $$({ env })`pnpm nx run dahlia:otterscan`;

const deployContracts = async (rpcPort: string, otterscanPort: string): Promise<void> => {
  const rpcUrl = `http://localhost:${rpcPort}`;
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);

  const blockNumber = await waitForRpc(rpcUrl);
  console.log("blockNumber=" + blockNumber);

  await $$({
    cwd: "..",
    env: {
      ...envs,
      OTTERSCAN_PORT: otterscanPort,
    },
  })`forge script script/DeployDahliaPythOracleFactory.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
};

// await deployContracts(process.env.MAINNET_RPC_PORT || "8546", process.env.MAINNET_OTT_PORT || "28546");
// await deployContracts(process.env.SEPOLIA_RPC_PORT || "8547", process.env.SEPOLIA_OTT_PORT || "28547");
await deployContracts(process.env.CARTIO_RPC_PORT || "8548", process.env.CARTIO_OTT_PORT || "28548");
