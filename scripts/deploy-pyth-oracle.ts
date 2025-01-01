import { execa } from "execa";
import * as process from "node:process";

import { envs, privateKey } from "./consts";
import { waitForRpc } from "./waitForRpc";

const $$ = execa({ verbose: "full" });

const deployContracts = async (rpcPort: string, otterscanPort: string): Promise<void> => {
  const rpcUrl = `http://localhost:${rpcPort}`;
  console.log(`Deploying contracts to rpcUrl=${rpcUrl}...`);

  const blockNumber = await waitForRpc(rpcUrl);
  console.log("blockNumber=" + blockNumber);

  await $$({
    cwd: "..",
    env: {
      ...envs,
      PYTH_ORACLE_BASE_TOKEN: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH_ERC20
      PYTH_ORACLE_BASE_FEED: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
      PYTH_ORACLE_QUOTE_TOKEN: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", // UNI_ERC20
      PYTH_ORACLE_QUOTE_FEED: "0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501",
      PYTH_ORACLE_BASE_MAX_DELAY: "86400",
      PYTH_ORACLE_QUOTE_MAX_DELAY: "86400",
      OTTERSCAN_PORT: otterscanPort,
    },
  })`forge script script/DahliaOracleFactory.PythOracle.s.sol --rpc-url ${rpcUrl} --broadcast --private-key ${privateKey}`;
};

await deployContracts(process.env.MAINNET_RPC_PORT || "8546", process.env.MAINNET_OTT_PORT || "28546");
// await deployContracts(process.env.SEPOLIA_RPC_PORT || "8547", process.env.SEPOLIA_OTT_PORT || "28547");
// await deployContracts(process.env.CARTIO_RPC_PORT || "8548", process.env.CARTIO_OTT_PORT || "28548");
