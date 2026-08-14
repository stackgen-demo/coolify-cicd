import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const manifest = JSON.parse(readFileSync("demo/baseline-manifest.json", "utf8"));
const failures = manifest.security_control_paths_absent.filter((path) => existsSync(path));

if (failures.length > 0) {
  throw new Error(`Reset baseline still contains injected controls: ${failures.join(", ")}`);
}

const status = execFileSync("git", ["status", "--porcelain"], { encoding: "utf8" }).trim();
if (status !== "") {
  throw new Error(`Reset branch is not clean after reverts:\n${status}`);
}

process.stdout.write("Reset baseline verified; runtime infrastructure and deployed artifact were not changed.\n");
