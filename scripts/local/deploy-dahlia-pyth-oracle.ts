import { clearPrefixOnEnvKeys, deployContractsToLocalCartio } from "../utils";

await deployContractsToLocalCartio("script/CreateDahliaPythOracle.s.sol", (envs) => {
  const withoutStone = clearPrefixOnEnvKeys(envs, "STONE_WETH");

  return clearPrefixOnEnvKeys(withoutStone, "PYTH");
});
await deployContractsToLocalCartio("script/CreateDahliaPythOracle.s.sol", (envs) => {
  const withoutBera = clearPrefixOnEnvKeys(envs, "WBERA_USDC");

  return clearPrefixOnEnvKeys(withoutBera, "PYTH");
});
