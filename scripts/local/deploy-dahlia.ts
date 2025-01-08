import { deployContractsToLocalMainnet, deployContractsToLocalSepolia, deployContractsToLocalCartio } from "../utils";

await deployContractsToLocalMainnet("script/Dahlia.s.sol");
await deployContractsToLocalSepolia("script/Dahlia.s.sol");
await deployContractsToLocalCartio("script/Dahlia.s.sol");
