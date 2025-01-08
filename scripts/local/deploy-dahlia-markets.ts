import { clearPrefixOnEnvKeys, deployContractsToLocalCartio } from "../utils";

await deployContractsToLocalCartio("script/WrappedVault.s.sol", (envs) => clearPrefixOnEnvKeys(envs, "STONE_WETH"));
await deployContractsToLocalCartio("script/WrappedVault.s.sol", (envs) => clearPrefixOnEnvKeys(envs, "WBERA_USDC"));
