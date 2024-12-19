import { execa } from "execa";
import { createPublicClient, http } from "viem";
import type { GetBlockNumberReturnType } from "viem";
import { mainnet } from "viem/chains";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };
const $$ = execa({ verbose: "full" });
const $ = execa({ env, verbose: "short" });

const rpcUrl = "http://localhost:8546";
const client = createPublicClient({ chain: mainnet, transport: http(rpcUrl) });

const waitForRpc = async (): Promise<GetBlockNumberReturnType> => {
  while (true) {
    const currentBlockNumber = await client.getBlockNumber();
    if (currentBlockNumber !== undefined) {
      return currentBlockNumber;
    }
    console.log("RPC is not ready yet, retrying...");
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Sleep for 1 second
  }
};

await $({ env })`pnpm nx run dahlia:otterscan`;

console.log("Deploying contracts...");

const blockNumber = await waitForRpc();
console.log("blockNumber=" + blockNumber);

// const { stdout } = await $$({cwd: "../lib/royco"})`forge create src/VaultOrderBook.sol:VaultOrderbook --rpc-url http://localhost:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`;
// if (!!stdout) {
//   const roycoAddress = stdout.match(/Deployed to: (0x[0-9a-fA-F]+)/)?.pop();
//   console.log('roycoAddress', roycoAddress);
// }

/**
 * Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
 * Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
 *
 * Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
 * Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
 *
 * Account #2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10000 ETH)
 * Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
 */
await $$({
  cwd: "..",
  env: {
    PRIVATE_KEY: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    DAHLIA_OWNER: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    DAHLIA_PRIVATE_KEY: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    FEES_RECIPIENT: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
  },
})`forge script script/Dahlia.s.sol --rpc-url http://localhost:8546 --broadcast`;
