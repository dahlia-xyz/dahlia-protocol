import { load } from "./config.ts";
import { Network, recreateDockerOtterscan, sendMoneyToAddressOnAnvil } from "./utils.ts";

await recreateDockerOtterscan();

for (const network of Object.values(Network)) {
  const cfg = load(network);
  const rpcUrl = `http://localhost:${cfg.RPC_PORT}`;
  await sendMoneyToAddressOnAnvil(rpcUrl, cfg.DAHLIA_OWNER, 10000000000000000000);
}
