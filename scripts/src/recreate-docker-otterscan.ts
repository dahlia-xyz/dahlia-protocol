import { load } from "./config.ts";
import { interceptAllOutput, recreateDockerOtterscan } from "./utils.ts";

await interceptAllOutput();

await recreateDockerOtterscan(false);
