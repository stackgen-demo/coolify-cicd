# Talkdesk Coolify Aiden Contract

## Goal

Deploy Aiden workflows that bootstrap missing CI security controls, review deterministic PR scan evidence, and perform bounded post-deployment security assurance for a sample application deployed to EC2 through Coolify.

## Managed Open Observability Stack

Use StackGen ObserveNow as the managed open stack:

- Metrics: VictoriaMetrics
- Logs: Loki
- Traces: Jaeger datasource backed by Zipkin v2 ingestion
- Visualization and alert evaluation: Grafana
- EC2 host collection: OpsVerse agent

The application emits OpenTelemetry to a local Collector sidecar. The Collector exports metrics by Prometheus Remote Write, logs by Loki OTLP HTTP, and traces by Zipkin v2 to `/api/v2/spans`.

Do not implement Datadog in v1. Keep instrumentation vendor-neutral so another Collector exporter can be added later.

## Demo Deployment Model

Every demo run redeploys the same reviewed application artifact by immutable image digest. The repository PR demonstrates security-control injection, deterministic scanning, review, and approval; it does not need to produce a different runtime artifact.

Trigger Coolify only from the dedicated deployment workflow by calling its authenticated deploy webhook. Do not enable unconditional Coolify auto-deploy for every push to the default branch. Pass a unique `demo_run_id` with each redeployment and propagate it through the deployment event, scanner evidence, application telemetry, Aiden assessment, and compliance report.

Record both the scanned repository commit SHA and the independently pinned image digest in the report. Do not claim source-to-artifact provenance unless a future version actually builds and attests the image from that commit.

## Aiden Resources

### Reused modules

- `aios-foundation`
- `aios-policies`
- `aios-integration-github`
- `aios-integration-ubuntu`
- `aios-integration-grafana`
- `aios-agent-supply-chain-security`
- `aios-agent-grafana-sre`

Pin every Git module source to the same reviewed tag or commit.

### Custom workflows

#### `security-control-bootstrap`

Stages:

1. Validate the allowlisted repository, default branch, triggering `demo-application`-labeled application PR, and its current head SHA.
2. Inventory active security workflows and required checks.
3. Compare them to the required control manifest.
4. If controls are missing, copy reviewed workflow templates into a dedicated branch and open one security-controls PR.
5. Validate that the controls PR is authored by the dedicated Aiden GitHub App, targets the expected default branch, uses the configured branch prefix, changes only allowlisted security-control paths, matches the reviewed template digest manifest, contains no binary, symlink, or submodule changes, and still has the head SHA that was validated.
6. Wait for every required controls-PR validation check to pass, then automatically merge the controls PR with the dedicated GitHub App. Do not submit an approval review.
7. Verify the merged controls on the default branch and configure or verify the required `security-gate` check.
8. Add one comment to the triggering application PR describing the controls added, controls PR URL, merge SHA, required check name, and next action. Do not include credentials or raw scanner output.
9. After the comment succeeds, automatically update the application PR branch from the default branch using GitHub's update-branch operation with the previously validated application head SHA as `expected_head_sha`.
10. Verify that the update produced a new application head SHA and started the deterministic security workflow. If the branch cannot be updated cleanly, comment with the conflict and stop.

The agent may create a branch and PR only for the configured repository. It has a single merge exception: its own security-controls PR may be automatically merged when every guard above passes. It never approves its own PR and never merges the triggering application PR or any other application-code PR.

Use a dedicated GitHub App identity for this workflow. Grant it only the repository permissions needed to create workflow files, comment, merge the controls PR, and update the application PR branch. If the repository requires reviews, add this App to the applicable ruleset bypass list as **For pull requests only**. The workflow's deterministic guards are mandatory because GitHub's bypass capability is granted to the App identity, not conditionally to a particular diff.

The automatic merge and branch update must be compare-and-swap operations: submit the controls PR merge only for the validated controls head SHA, and submit the application update only for the captured application `expected_head_sha`. A concurrent change invalidates the operation and requires a new validation pass.

#### `pr-security-review`

Trigger only after the deterministic GitHub workflow completes. Required inputs are repository, PR number, workflow run ID, and commit SHA.

Read Gitleaks, Semgrep, Trivy, unit/auth, IaC, and OPA results. Deduplicate findings, distinguish blocking from advisory results, and publish one concise PR comment. The agent does not change the deterministic `security-gate` conclusion.

#### `postdeploy-adversarial-assurance`

Required inputs include repository, commit SHA, image digest, Coolify deployment UUID, target URL, AWS region, and evidence artifact/run ID.

Stages:

1. Validate that the hostname and deployment identifiers match the allowlist.
2. Read AWS posture evidence for ALB, WAF, TLS, security-group ingress/egress, and EC2 management exposure.
3. Read Nmap, ZAP, authentication, header, and TLS scan artifacts.
4. Run bounded follow-up HTTP probes only when evidence justifies them.
5. Query ObserveNow for the deployment correlation ID across metrics, logs, and traces.
6. Evaluate the policy control catalog.
7. Publish one redacted compliance assessment.

Active probes must have a ten-minute maximum, an explicit host allowlist, a request cap, and no destructive methods, denial-of-service, persistence, credential stuffing, or lateral movement.

## Demo Reset

Reset only repository and GitHub control state. Do not tear down or modify EC2, ALB, WAF, Coolify, the running application, Aiden resources, Grafana, the OpsVerse agent, or the OpenTelemetry pipeline. Do not invoke the Coolify deploy webhook during reset.

Use a deterministic, manually dispatched reset workflow with a protected `demo-reset` environment. It must require no operator-entered run metadata: discover the prior demo context from the latest merged security-controls PR, its linked application PR, static workflow variables, and the last deployment workflow record. It must:

1. Use dedicated reset and replay branch guards so Aiden ignores reset PRs and the initial creation of the closed replay PR.
2. Record the completed run ID, application PR, controls PR, merge SHAs, deployment UUID, artifact digest, and report location.
3. Retain the demo-installed `security-gate` requirement so the baseline remains protected; the next controls PR restores its workflow before the replay application PR is advanced.
4. Restore the repository working tree by reverting the known application and security-controls merge commits. Create revert commits or a reset PR; never force-push or rewrite the default branch.
5. Preserve all historic demo PRs and branches so prior runs remain available for the demonstration. Create a new closed, labeled replay application PR from the reset baseline, retain its branch, and clearly instruct the operator to reopen it to trigger the next demo run.
6. Verify that the repository matches the declared baseline manifest and that the security workflow files and policies installed by the demo are absent.
7. Leave repository Actions variables unchanged and re-enable the bootstrap trigger when the operator reopens the replay PR.

Preserve Aiden execution history, compliance reports, Coolify deployment history, and observability data. Dashboards must filter by `demo_run_id` so previous runs remain available without contaminating the next demonstration.

The reset workflow is not covered by the security-controls no-HITL merge exception. Reset requires explicit operator dispatch and any approval configured on the protected `demo-reset` environment. It uses the scoped GitHub Actions token with `actions: read`, `contents: write`, and `pull-requests: write`; it has no separately managed reset-token prerequisite.

## Deterministic Controls

Agents explain and correlate; these controls decide pass/fail:

- No verified secret leaks.
- No verified secret leaks or blocking SAST findings. High/critical Trivy dependency, filesystem, IaC, and image findings are advisory in the pre-deployment demo report; they must be redacted, attributed, and carried into the post-deployment compliance report.
- EC2 has no public SSH or Coolify administration port.
- ALB exposes only HTTP/HTTPS and redirects HTTP to HTTPS.
- EC2 application ingress is sourced only from the ALB security group.
- Egress is limited to the documented HTTPS dependencies.
- WAF is attached and blocks malformed required headers.
- Missing, malformed, expired, wrong-signature, and wrong-audience JWTs are rejected.
- OpsVerse agent and application Collector are healthy.
- A deployment correlation ID is visible in VictoriaMetrics, Loki, and the trace datasource.

## Grafana

Use a dedicated Grafana Terraform service account, not the administrator password. On the configured development machine the current provisioner token is stored in macOS Keychain:

```bash
export GRAFANA_AUTH="$(security find-generic-password \
  -a talkdesk-coolify \
  -s com.stackgen.talkdesk-coolify.grafana \
  -w)"
```

Never print `GRAFANA_AUTH`. The token is time-limited; create a replacement service-account token when expired.

Known datasource UIDs in the demo ObserveNow instance:

- Metrics: `metrics`
- Logs: `loki`
- Jaeger traces: `jaeger`
- Tempo traces: `dfar9p0xnvgg0f`
- CloudWatch: `afimxw4vghbeoc`

Discover and verify UIDs again before apply. Provision dashboards and evaluating alert rules, but no contact points or notification policies; the user owns routing.

## Secret Boundaries

- StackGen PAT: environment only.
- GitHub/AWS/Grafana integration credentials: existing Guild secret IDs where possible.
- Grafana provisioner token: local keychain/environment only.
- ObserveNow backend writer and OpsVerse agent tokens: AWS Secrets Manager and Coolify runtime secrets only.
- Coolify deploy token and Aiden webhook tokens: GitHub Actions secrets only.

## Required Outputs

Expose workflow and agent names, non-secret webhook endpoints, Grafana dashboard URLs, report bucket/prefix, scanned commit SHA, immutable image digest, and `demo_run_id`. Mark webhook tokens and credential-bearing URLs sensitive. The deployment report must confirm that the Terraform plan contained zero deletes.
