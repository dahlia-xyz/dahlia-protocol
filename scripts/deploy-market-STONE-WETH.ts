import { execa } from "execa";
import * as process from "node:process";

import { privateKey } from "./envs";

const $$ = execa({ verbose: "full" });

const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;

if (!deployerPrivateKey) {
  throw new Error("Missing DEPLOYER_PRIVATE_KEY");
}

const deployContracts = async (rpcUrl: string, otterscanPort: string): Promise<void> => {
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);

  await $$({
    cwd: "..",
    env: {
      PRIVATE_KEY: deployerPrivateKey,
      DAHLIA_OWNER: "0x56929D12646A2045de60e16AA28b8b4c9Dfb0441",
      NAME: "STONE/WETH (92% LLTV)",
      COLLATERAL: "0x1da4dF975FE40dde074cBF19783928Da7246c515", // STONE https://80000.testnet.routescan.io/address/0x1da4dF975FE40dde074cBF19783928Da7246c515
      LOAN: "0x2d93FbcE4CffC15DD385A80B3f4CC1D4E76C38b3", // WETH https://80000.testnet.routescan.io/token/0x2d93FbcE4CffC15DD385A80B3f4CC1D4E76C38b3
      ORACLE: "0xe3b61f75d2457e34f11bb01f945a6c7336518e43", // https://80000.testnet.routescan.io/address/0xe3b61f75d2457e34f11bb01f945a6c7336518e43/contract/80000/code
      IRM: "0x651ee694a70835225a25cfc5f374f8a9913b9845", // https://80000.testnet.routescan.io/address/0x651Ee694a70835225A25CFc5f374f8A9913b9845/contract/80000/code
      LLTV: "92000", // 92%
      LIQUIDATION_BONUS_RATE: "6000", // 6%
      OTTERSCAN_PORT: otterscanPort,
      DAHLIA_ADDRESS: "0x0a7e67a977cf9ab1de3781ec58625010050e446e",
    },
  })`forge script script/WrappedVault.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
};

await deployContracts(
  process.env.CARTIO_RPC_URL || "https://teddilion-eth-cartio.berachain.com",
  process.env.CARTIO_OTT_PORT || "28548",
);
