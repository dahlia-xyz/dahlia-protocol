import { deployContractsToMainnet, deployContractsToSepolia, deployContractsToCartio } from "../utils.ts";

await deployContractsToMainnet("script/Dahlia.s.sol");
await deployContractsToSepolia("script/Dahlia.s.sol");
await deployContractsToCartio("script/Dahlia.s.sol");
