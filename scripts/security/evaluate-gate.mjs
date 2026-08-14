import fs from "node:fs";

const names = ["gitleaks", "semgrep", "trivy", "tests", "policies"];
const results = Object.fromEntries(names.map((name) => [name, process.env[`${name.toUpperCase()}_RESULT`] ?? "missing"]));
const failures = Object.entries(results)
  .filter(([, result]) => result !== "success")
  .map(([control, result]) => ({ control, result }));

fs.mkdirSync("evidence", { recursive: true });
fs.writeFileSync(
  "evidence/security-gate.json",
  `${JSON.stringify({ allow: failures.length === 0, failures, results }, null, 2)}\n`,
  { mode: 0o600 },
);

if (failures.length > 0) {
  process.stderr.write(`security gate failed: ${failures.map(({ control, result }) => `${control}=${result}`).join(", ")}\n`);
  process.exit(1);
}
