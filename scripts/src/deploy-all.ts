import { DEPLOY_ON_REMOTE } from "../envs.ts";
import { deployContractsOnNetworks } from "../utils.ts";

if (DEPLOY_ON_REMOTE) {
  throw new Error(
    "You are trying to deploy on remote all in once, before deleting this blocker - make sure you know what are you doing.",
  );
}

await import("./recreate-docker-otterscan.ts");
await deployContractsOnNetworks("script/DeployIrmFactory.s.sol");
await deployContractsOnNetworks("script/CreateVariableIrm.s.sol", "VariableIRMs");
await deployContractsOnNetworks("script/Dahlia.s.sol");
await deployContractsOnNetworks("script/DeployTimelock.s.sol");
await deployContractsOnNetworks("script/DeployDahliaPythOracleFactory.s.sol");
await deployContractsOnNetworks("script/CreateDahliaPythOracle.s.sol", "PythOracles");
await deployContractsOnNetworks("script/WrappedVault.s.sol", "WrappedVaults");
