import { deployContractsOnNetworks, DEPLOY_ON_REMOTE } from "../utils.ts";

if (DEPLOY_ON_REMOTE) {
  throw new Error(
    "You are trying to deploy on remote all in once, before deleting this blocker - make sure you know what are you doing.",
  );
}

await import("./recreate-docker-otterscan.ts");
await deployContractsOnNetworks("DeployIrmFactory.s.sol");
await deployContractsOnNetworks("CreateVariableIrm.s.sol", "VariableIRMs");
await deployContractsOnNetworks("Dahlia.s.sol");
await deployContractsOnNetworks("DeployTimelock.s.sol");
await deployContractsOnNetworks("DeployDahliaPythOracleFactory.s.sol");
await deployContractsOnNetworks("CreateDahliaPythOracle.s.sol", "PythOracles");
await deployContractsOnNetworks("WrappedVault.s.sol", "WrappedVaults");
