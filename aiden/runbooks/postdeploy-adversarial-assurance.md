# Post-deployment adversarial assurance SOP

1. Validate the repository, immutable image digest format, Coolify deployment UUID, evidence workflow run, report location, AWS region, target URL, and demo run ID.
2. Require the target hostname to match the configured allowlist and require a successful Coolify deployment record.
3. Read normalized evidence and original artifacts for Nmap, ZAP, TLS/HTTPS, WAF header probes, authentication probes, ALB listeners, WAF association, EC2 security-group ingress/egress, and management-port exposure.
4. Confirm the same demo run ID appears in VictoriaMetrics, Loki, and Jaeger, and confirm the OpsVerse host metric query has a live result.
5. Run a follow-up HTTP probe only to resolve a concrete evidence discrepancy. Limit the entire stage to ten minutes, 100 requests, the exact hostname, and GET/HEAD/OPTIONS.
6. Read the OPA policy decision. It is authoritative; do not turn a failure into a pass.
7. Publish exactly one redacted assessment containing source commit, independently pinned image digest, deployment UUID, demo run ID, pass/fail, control-by-control evidence, artifact/report links, and the explicit statement that the demo does not claim source-to-artifact provenance.
