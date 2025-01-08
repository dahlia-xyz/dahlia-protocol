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
      NAME: "WBERA/USDC (80% LLTV)",
      COLLATERAL: "0x6969696969696969696969696969696969696969", // WBERA https://80000.testnet.routescan.io/token/0x6969696969696969696969696969696969696969
      LOAN: "0x015fd589F4f1A33ce4487E12714e1B15129c9329", // USDC https://80000.testnet.routescan.io/token/0x015fd589F4f1A33ce4487E12714e1B15129c9329
      ORACLE: "0x5e9d4e86741d384d52fd2054f523692376ec6ce6", // https://80000.testnet.routescan.io/address/0x5e9D4E86741D384D52fd2054F523692376Ec6cE6/contract/80000/code
      IRM: "0x651ee694a70835225a25cfc5f374f8a9913b9845", // https://80000.testnet.routescan.io/address/0x651Ee694a70835225A25CFc5f374f8A9913b9845/contract/80000/code
      LLTV: "80000", // 80%
      LIQUIDATION_BONUS_RATE: "15000", // 20%
      OTTERSCAN_PORT: otterscanPort,
      DAHLIA_ADDRESS: "0x0a7e67a977cf9ab1de3781ec58625010050e446e",
    },
  })`forge script script/WrappedVault.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
};

await deployContracts(
  process.env.CARTIO_RPC_URL || "https://teddilion-eth-cartio.berachain.com",
  process.env.CARTIO_OTT_PORT || "28548",
);
