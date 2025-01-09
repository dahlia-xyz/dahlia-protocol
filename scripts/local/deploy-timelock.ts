import { deployContractsToMainnet, deployContractsToSepolia, deployContractsToCartio } from "../utils.ts";

await deployContractsToMainnet("script/DeployTimelock.s.sol");
await deployContractsToSepolia("script/DeployTimelock.s.sol");
await deployContractsToCartio("script/DeployTimelock.s.sol");
