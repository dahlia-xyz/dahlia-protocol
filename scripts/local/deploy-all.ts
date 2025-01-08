import { DEPLOY_ON_REMOTE } from "../utils";

if (DEPLOY_ON_REMOTE) {
  throw new Error(
    "You are trying to deploy on remote all in once, before deleting this blocker - make sure you know what are you doing.",
  );
}

await import("./recreate-docker-otterscan.ts");
await import("./deploy-dahlia.ts");
await import("./deploy-timelock.ts");
await import("./deploy-dahlia-pyth-oracle-factory.ts");
await import("./deploy-dahlia-pyth-oracle.ts");
await import("./deploy-dahlia-markets.ts");
