import { execa } from "execa";
import * as process from "node:process";
import { createPublicClient, http } from "viem";
import type { GetBlockNumberReturnType } from "viem";
import { mainnet } from "viem/chains";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };
const $$ = execa({ verbose: "full" });
// const $ = execa({ env, verbose: "short" });

const waitForRpc = async (rpcUrl: string): Promise<GetBlockNumberReturnType> => {
  const client = createPublicClient({ chain: mainnet, transport: http(rpcUrl) });

  while (true) {
    let currentBlockNumber = undefined;
    try {
      currentBlockNumber = await client.getBlockNumber();
    } catch (err) {}
    if (currentBlockNumber !== undefined) {
      return currentBlockNumber;
    }
    console.log("RPC is not ready yet, retrying...");
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Sleep for 1 second
  }
};

await $$({ env })`pnpm nx run dahlia:otterscan`;

const deployContracts = async (rpcPort: string, otterscanPort: string): Promise<void> => {
  const rpcUrl = `http://localhost:${rpcPort}`;
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);

  const blockNumber = await waitForRpc(rpcUrl);
  console.log("blockNumber=" + blockNumber);

  // const { stdout } = await $$({cwd: "../lib/royco"})`forge create src/VaultOrderBook.sol:VaultOrderbook --rpc-url http://localhost:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`;
  // if (!!stdout) {
  //   const roycoAddress = stdout.match(/Deployed to: (0x[0-9a-fA-F]+)/)?.pop();
  //   console.log('roycoAddress', roycoAddress);
  // }

  /**
   * Available Accounts
   * ==================
   *
   * (0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000.000000000000000000 ETH)
   * (1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000.000000000000000000 ETH)
   * (2) 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10000.000000000000000000 ETH)
   * (3) 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (10000.000000000000000000 ETH)
   * (4) 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 (10000.000000000000000000 ETH)
   * (5) 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc (10000.000000000000000000 ETH)
   * (6) 0x976EA74026E726554dB657fA54763abd0C3a0aa9 (10000.000000000000000000 ETH)
   * (7) 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 (10000.000000000000000000 ETH)
   * (8) 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f (10000.000000000000000000 ETH)
   * (9) 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (10000.000000000000000000 ETH)
   *
   * Private Keys
   * ==================
   *
   * (0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   * (1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
   * (2) 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
   * (3) 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
   * (4) 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
   * (5) 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
   * (6) 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
   * (7) 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
   * (8) 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
   * (9) 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
   */
  let private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  await $$({
    cwd: "..",
    env: {
      PRIVATE_KEY: private_key,
      DAHLIA_OWNER: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      DAHLIA_PRIVATE_KEY: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
      FEES_RECIPIENT: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
      POINTS_FACTORY: "0x19112AdBDAfB465ddF0b57eCC07E68110Ad09c50",
      OTTERSCAN_PORT: otterscanPort,
    },
  })`forge script script/Dahlia.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${private_key}`;
};

await deployContracts(process.env.MAINNET_RPC_PORT || "8546", process.env.MAINNET_OTT_PORT || "28546");
await deployContracts(process.env.SEPOLIA_RPC_PORT || "8547", process.env.SEPOLIA_OTT_PORT || "28547");
await deployContracts(process.env.CARTIO_RPC_PORT || "8548", process.env.CARTIO_OTT_PORT || "28548");
