import { deployerWalletAddress } from "../envs.ts";
import {
  recreateDockerOtterscan,
  sendMoneyToAddressOnAnvilCartio,
  sendMoneyToAddressOnAnvilMainnet,
  sendMoneyToAddressOnAnvilSepolia,
} from "../utils.ts";

await recreateDockerOtterscan();

// Send 10 of chain currency to deployer
await sendMoneyToAddressOnAnvilMainnet(deployerWalletAddress, 10000000000000000000);
await sendMoneyToAddressOnAnvilSepolia(deployerWalletAddress, 10000000000000000000);
await sendMoneyToAddressOnAnvilCartio(deployerWalletAddress, 10000000000000000000);
