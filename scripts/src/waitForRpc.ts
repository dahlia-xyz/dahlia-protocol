import type { GetChainIdReturnType } from "viem";
import { createPublicClient, http } from "viem";
import { mainnet } from "viem/chains";

export const waitForRpc = async (rpcUrl: string): Promise<GetChainIdReturnType> => {
  const client = createPublicClient({ chain: mainnet, transport: http(rpcUrl) });

  while (true) {
    let result = undefined;
    try {
      result = await client.getChainId();
    } catch (err) {}
    if (result !== undefined) {
      return result;
    }
    console.log(`RPC ${rpcUrl} is not ready yet, retrying...`);
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Sleep for 1 second
  }
};
