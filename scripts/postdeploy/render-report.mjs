import fs from "node:fs";

const evidence = JSON.parse(fs.readFileSync("evidence/postdeploy.json", "utf8"));
const envelope = JSON.parse(fs.readFileSync("evidence/policy-decision.json", "utf8"));
const decision = envelope.result?.[0]?.expressions?.[0]?.value ?? { allow: false, deny: ["OPA returned no decision"] };
const rejectedAuthCases = ["missing", "malformed", "expired", "wrong_signature", "wrong_audience"].every(
  (name) => evidence.authentication[name] === 401,
);
const controls = [
  ["Public ports limited to HTTP/HTTPS", evidence.network.open_ports.every((port) => [80, 443].includes(port)), evidence.network.open_ports.join(", ")],
  ["HTTPS redirect and TLS validation", evidence.https.redirect_enforced && evidence.https.tls_valid, `redirect=${evidence.https.redirect_enforced}, tls=${evidence.https.tls_valid}`],
  ["AWS WAF attached", evidence.aws.waf_attached, String(evidence.aws.waf_attached)],
  ["AWS WAF required-header behavior", evidence.waf.missing_header_blocked && evidence.waf.malformed_header_blocked && evidence.waf.valid_header_allowed, JSON.stringify(evidence.waf)],
  ["ALB ingress restricted to 80/443", evidence.aws.alb_ingress_restricted, String(evidence.aws.alb_ingress_restricted)],
  ["ALB egress restricted to EC2:3000", evidence.aws.alb_egress_restricted, String(evidence.aws.alb_egress_restricted)],
  ["EC2 ingress restricted to ALB:3000", evidence.aws.ingress_from_alb_only, String(evidence.aws.ingress_from_alb_only)],
  ["EC2 egress restricted to HTTPS/DNS", evidence.aws.egress_restricted, String(evidence.aws.egress_restricted)],
  ["No public SSH or Coolify management port", !evidence.aws.management_port_public, String(!evidence.aws.management_port_public)],
  ["Invalid JWT cases rejected", rejectedAuthCases && evidence.authentication.valid === 200, JSON.stringify(evidence.authentication)],
  ["Metrics, logs, and traces correlated", evidence.observability.correlation_complete, JSON.stringify(evidence.observability)],
  ["OpsVerse infrastructure agent healthy", evidence.observability.opsverse_agent_healthy, String(evidence.observability.opsverse_agent_healthy)],
];
const lines = [
  "# Post-deployment compliance report",
  "",
  `- Demo run: \`${evidence.demo_run_id}\``,
  `- Source commit: \`${evidence.source_commit_sha}\``,
  `- Image digest: \`${evidence.image_digest}\``,
  `- Coolify deployment: \`${evidence.deployment_uuid}\``,
  `- Policy result: **${decision.allow ? "PASS" : "FAIL"}**`,
  "",
  "## Control results",
  "",
  "| Control | Result | Evidence summary |",
  "|---|---:|---|",
  ...controls.map(([name, passed, summary]) => `| ${name} | ${passed ? "PASS" : "FAIL"} | \`${summary}\` |`),
  "",
  "## Findings",
  "",
  ...(decision.deny?.length ? decision.deny.map((reason) => `- ${reason}`) : ["- No policy violations detected."]),
  "",
  "This report records the scanned commit and independently pinned image digest; it does not claim source-to-artifact provenance.",
  "",
];
fs.mkdirSync("reports/generated", { recursive: true });
fs.writeFileSync(`reports/generated/${evidence.demo_run_id}.md`, lines.join("\n"), { mode: 0o600 });
