import { clearPrefixOnEnvKeys, deployContractsToCartio } from "../utils";

await deployContractsToCartio("script/WrappedVault.s.sol", (envs) => clearPrefixOnEnvKeys(envs, "STONE_WETH"));
await deployContractsToCartio("script/WrappedVault.s.sol", (envs) => clearPrefixOnEnvKeys(envs, "WBERA_USDC"));
