import { clearPrefixOnEnvKeys, deployContractsToLocalCartio } from "../utils";

await deployContractsToLocalCartio("script/DeployDahliaPythOracleFactory.s.sol", (envs) =>
  clearPrefixOnEnvKeys(envs, "PYTH"),
);
