import { execa } from "execa";
import * as process from "node:process";

import { waitForRpc } from "./waitForRpc";

const $$ = execa({ verbose: "full" });
const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };
// await $$({ env })`pnpm nx run dahlia:otterscan`;

const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;

if (!deployerPrivateKey) {
  throw new Error("Missing DEPLOYER_PRIVATE_KEY");
}

const deployContracts = async (rpcUrl: string, otterscanPort: string): Promise<void> => {
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);

  const blockNumber = await waitForRpc(rpcUrl);
  console.log("blockNumber=" + blockNumber);

  // WBERA/USDC
  await $$({
    cwd: "..",
    env: {
      PRIVATE_KEY: deployerPrivateKey,
      DAHLIA_OWNER: "0x56929D12646A2045de60e16AA28b8b4c9Dfb0441",
      PYTH_STATIC_ORACLE_ADDRESS: "0xDd24F84d36BF92C65F92307595335bdFab5Bbd21",
      PYTH_ORACLE_BASE_TOKEN: "0x6969696969696969696969696969696969696969", // WBERA
      PYTH_ORACLE_BASE_FEED: "0x40dd8c66a9582c51a1b03a41d6c68ee5c2c04c8b9c054e81d0f95602ffaefe2f",
      PYTH_ORACLE_QUOTE_TOKEN: "0x015fd589F4f1A33ce4487E12714e1B15129c9329", // USDC
      PYTH_ORACLE_QUOTE_FEED: "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722",
      PYTH_ORACLE_BASE_MAX_DELAY: "86400",
      PYTH_ORACLE_QUOTE_MAX_DELAY: "86400",
      OTTERSCAN_PORT: otterscanPort,
    },
  })`forge script script/DeployPythOracle.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${deployerPrivateKey}`;
  // STONE/WETH
  await $$({
    cwd: "..",
    env: {
      PRIVATE_KEY: deployerPrivateKey,
      DAHLIA_OWNER: "0x56929D12646A2045de60e16AA28b8b4c9Dfb0441",
      PYTH_STATIC_ORACLE_ADDRESS: "0xDd24F84d36BF92C65F92307595335bdFab5Bbd21",
      PYTH_ORACLE_BASE_TOKEN: "0x1da4dF975FE40dde074cBF19783928Da7246c515", // STONE
      PYTH_ORACLE_BASE_FEED: "0xc1304032f924ebde0d52dd804ff7e7d095f7b4d4eff809cae7f12b7136e089c0",
      PYTH_ORACLE_QUOTE_TOKEN: "0x2d93FbcE4CffC15DD385A80B3f4CC1D4E76C38b3", // WETH
      PYTH_ORACLE_QUOTE_FEED: "0x86d196443d86a992f6c4ce38779cdfa36b649e43052ef8bedbe0b503029a94c2",
      PYTH_ORACLE_BASE_MAX_DELAY: "86400",
      PYTH_ORACLE_QUOTE_MAX_DELAY: "86400",
      OTTERSCAN_PORT: otterscanPort,
    },
  })`forge script script/DeployPythOracle.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${deployerPrivateKey}`;
};

// await deployContracts(process.env.MAINNET_RPC_PORT || "8546", process.env.MAINNET_OTT_PORT || "28546");
// await deployContracts(process.env.SEPOLIA_RPC_PORT || "8547", process.env.SEPOLIA_OTT_PORT || "28547");
await deployContracts(process.env.CARTIO_RPC_URL, process.env.CARTIO_OTT_PORT || "28548");
