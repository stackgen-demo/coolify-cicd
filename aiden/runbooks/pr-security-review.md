# PR security review SOP

1. Validate repository, PR number, workflow run ID, and latest PR SHA.
2. Require the run to be the `Security gate` workflow for the supplied SHA.
3. Read all available Gitleaks, Semgrep, Trivy, test, policy, and aggregate gate artifacts. Missing evidence is a blocking evidence-quality finding.
4. Redact credential-like values and source excerpts. Deduplicate findings by scanner rule, path, package/CVE, and root cause.
5. Treat high and critical findings in the Trivy artifact as advisory demo-report findings when the Trivy job completed successfully; report their rule/CVE, sanitized path or resource, severity, and remediation. A Trivy execution error or missing evidence remains blocking. Classify all other findings as blocking only when their deterministic job or aggregate gate failed. Do not invent exceptions or change GitHub check state.
6. Post exactly one comment with gate status, blocking findings, advisory findings, evidence links, and next actions. Update the existing Aiden comment if the workflow is re-run instead of creating duplicates.
