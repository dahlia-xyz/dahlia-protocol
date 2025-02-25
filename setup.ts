import { Command } from "commander";
import { execa } from "execa";
import fse from "fs-extra/esm";
import fs from "fs/promises";

const env = { ...process.env, NX_VERBOSE_LOGGING: "true" };
const $$ = execa({ env, verbose: "full" });
const $ = execa({ env, verbose: "short" });

const program = new Command();

async function prepareSubmodules() {
  await $`git submodule update --init`;
  // await $({ cwd: "../lib/royco" })`git submodule deinit lib/solmate`;
  // await $({ cwd: "../lib/royco" })`git submodule deinit lib/solady`;
  // await $({ cwd: "../lib/royco" })`git submodule deinit lib/openzeppelin-contracts`;
  //await $({ cwd: "../" })`forge clean`;
}

program.command("init").action(async () => {
  console.log("Running init...");

  const checkCommand = async (commandName: string): Promise<void> => {
    try {
      await $$`which ${commandName}`;
    } catch {
      console.error(`Command [${commandName}] is not available. Please install it.`);
      process.exit(1);
    }
  };

  // Verify environment
  console.log("Running setup...");
  // Verify environment
  await checkCommand("forge");
  await $`pnpm husky`;
  await $`forge install`;
  // await $`pip3 install slither-analyzer`;
  await prepareSubmodules();

  console.log("Setup complete!");
});

program.command("generate-abi").action(async () => {
  console.log("Running generate-abi...");
  fse.mkdirsSync("./abis");
  const contracts = [
    "IDahlia",
    "IDahliaLiquidateCallback",
    "IDahliaRepayCallback",
    "IDahliaSupplyCollateralCallback",
    "IDahliaRegistry",
    "IPermitted",
    "IrmFactory",
    "IIrm",
    "ChainlinkWstETHToETH",
    "DahliaChainlinkOracle",
    "DahliaChainlinkOracleFactory",
    "DahliaPythOracle",
    "DahliaPythOracleFactory",
    "DahliaDualOracle",
    "DahliaDualOracleFactory",
    "DahliaPythAdvOracle",
    "DahliaPythAdvOracleFactory",
    "DahliaUniswapV3Oracle",
    "DahliaUniswapV3OracleFactory",
    "Timelock",
    "IDahliaOracle",
    "IDahliaWrappedVault",
  ];
  await Promise.all(
    contracts.map(async (contract) => {
      const { stdout } = await $`forge inspect ${contract} abi`;
      await fs.writeFile(`./abis/${contract}.json`, stdout);
    }),
  );
  await $`prettier --write ./abis/*.json`;
});

await program.parseAsync(process.argv);
