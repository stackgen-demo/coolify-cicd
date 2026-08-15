# Demo deployment and operation runbook

## 1. Configure and separate credentials

Store each deployment credential in its intended secret store and never commit it to the repository.

Use separate credentials for separate duties:

- an OpsVerse token in AWS Secrets Manager for the EC2 installer;
- ObserveNow writer credentials only in Coolify runtime secrets and GitHub deployment secrets;
- a Grafana provisioning service-account token for Terraform;
- a different read-only Grafana service-account token for Aiden and post-deployment queries;
- dedicated GitHub App credentials in the Aiden vault for control bootstrap;
- Coolify and Aiden webhook tokens only in GitHub Actions secrets.

To satisfy the one-time Grafana administrator requirement, sign in as an administrator, create a service account with only folder/dashboard/alert provisioning access, create its token, store it in the documented macOS Keychain item, then stop using the admin login for Terraform. Never commit or print the token.

## 2. Build and publish the immutable app image

Build the reviewed application once for the EC2 architecture and push it to the chosen registry:

```bash
docker buildx build --platform linux/amd64 --push \
  --tag REGISTRY/talkdesk-coolify-demo:reviewed app
docker buildx imagetools inspect REGISTRY/talkdesk-coolify-demo:reviewed
```

Record the resulting full `REGISTRY/name@sha256:...` reference. Use that exact value for Coolify's `DEMO_IMAGE_REFERENCE`; set the digest portion as the GitHub `DEMO_IMAGE_DIGEST` variable. The demo intentionally redeploys this same artifact on every run.

## 3. Provision AWS

Create an ACM certificate for the application hostname and an AWS Secrets Manager secret containing only the OpsVerse agent token. If the account already has the GitHub Actions OIDC provider, include its ARN and the repository `owner/name` in `infra/aws` variables.

```bash
cd infra/aws
tofu init
tofu plan -out=tfplan
tofu show -json tfplan | jq -e \
  '[.resource_changes[].change.actions | select(index("delete"))] | length == 0'
tofu apply tfplan
```

Copy the ALB ARN, ALB/EC2 security-group IDs, application URL, and GitHub post-deployment role ARN outputs to the corresponding GitHub variables. Use the SSM port-forward command output to reach Coolify administration; do not expose ports 22 or 8000 publicly.

## 4. Configure Coolify

1. Open Coolify through the SSM tunnel and create a Docker Compose resource rooted at `app/` with `docker-compose.yml`.
2. Set `DEMO_IMAGE_REFERENCE` to the immutable registry digest.
3. Add runtime values for `AUTH_ISSUER`, `AUTH_AUDIENCE`, `AUTH_HS256_SECRET`, `DEPLOYMENT_ENVIRONMENT`, `VICTORIA_METRICS_URL`, `LOKI_URL`, `JAEGER_ZIPKIN_URL`, `OBSERVENOW_USERNAME`, and `OBSERVENOW_PASSWORD`.
4. Disable unconditional repository auto-deploy. Generate a deploy webhook and API token for the dedicated GitHub deployment workflow.
5. Route host port 3000 to the ALB target group and verify `/healthz` is healthy.

During a demo, Coolify's Deployments page is the visualizer: it shows queued/running/finished state and live deployment logs. The GitHub job records the same deployment UUID and polls `GET /api/v1/deployments/{uuid}` for status.

## 5. Provision Grafana

Confirm the current data-source UIDs before apply. The defaults are `metrics`, `loki`, `jaeger`, and `afimxw4vghbeoc` for CloudWatch.

```bash
export TF_VAR_grafana_auth="$(security find-generic-password \
  -a talkdesk-coolify \
  -s com.stackgen.talkdesk-coolify.grafana \
  -w)"
tofu -chdir=infra/grafana init
tofu -chdir=infra/grafana plan -out=tfplan
tofu -chdir=infra/grafana apply tfplan
unset TF_VAR_grafana_auth
```

The dashboard filters by `demo_run_id`, so previous runs remain visible but do not contaminate the current run.

## 6. Deploy Aiden Automations

Follow `skills/aiden-workflow-deployer/SKILL.md`. Provide only the StackGen URL, PAT, and exact human workspace name to the deploying agent. It resolves the workspace UUID, discovers/reuses existing secret IDs and integrations, produces a saved additive plan, rejects deletes/replacements, and applies only the reviewed plan.

The root creates these Automation webhook targets:

- `security-control-bootstrap-talkdesk-demo`: called when an application PR opens;
- `pr-security-review-talkdesk-demo`: called after deterministic PR jobs finish;
- `postdeploy-adversarial-assurance-talkdesk-demo`: called after deployment evidence is collected.

The sensitive `webhook_payload_urls` output contains authenticated trigger URLs. Store them directly as GitHub secrets; do not print them.

## 7. Configure GitHub

Set these repository variables:

- `AWS_REGION`, `POSTDEPLOY_AWS_ROLE_ARN`, `ALB_ARN`, `ALB_SECURITY_GROUP_ID`, `EC2_SECURITY_GROUP_ID`, `EVIDENCE_BUCKET`;
- `DEMO_TARGET_URL`, `DEMO_ALLOWED_HOST`, `DEMO_IMAGE_DIGEST`, `DEMO_STATE=ready`;
- `COOLIFY_BASE_URL`;
- `WAF_HEADER_NAME`, `WAF_HEADER_VALUE`, `AUTH_ISSUER`, `AUTH_AUDIENCE`;
- `GRAFANA_URL`, `JAEGER_DATASOURCE_UID`, `LOKI_URL`, `VICTORIA_METRICS_QUERY_URL`, `OPSVERSE_METRIC_QUERY`;
- `SECURITY_CONTROL_BOT_LOGIN` matching the dedicated GitHub App login exactly.

Set these Actions secrets:

- `AIDEN_BOOTSTRAP_WEBHOOK_URL`, `AIDEN_PR_REVIEW_WEBHOOK_URL`, `AIDEN_POSTDEPLOY_WEBHOOK_URL`;
- `COOLIFY_DEPLOY_WEBHOOK`, `COOLIFY_TOKEN`;
- `AUTH_HS256_SECRET`;
- `OBSERVENOW_USERNAME`, `OBSERVENOW_PASSWORD`, `GRAFANA_READER_TOKEN`;
- `RESET_GITHUB_TOKEN`, scoped only for the protected reset job.

Create protected environments `demo-deploy` and `demo-reset`; require operator approval for reset. Require normal human review for application PRs. The dedicated GitHub App may bypass only the controls-PR ruleset and only for pull requests.

## 8. Run and reset

Open an application PR labeled `demo-application`. Watch the two PRs, the injected security jobs, the Aiden comments, Coolify's deployment view, the GitHub post-deployment job, and the Grafana dashboard.

After the report is complete, manually dispatch `Reset Talkdesk demo` from `main`. No run metadata needs to be entered: the workflow discovers the prior controls/application PR lineage, static demo variables, and the latest deployment workflow itself. The reset reverts repository state only. It retains all historic PRs and their branches, then creates a new closed replay application PR. Reopen that PR to start the next demo. The same immutable app remains running; Coolify deployment history, reports, Aiden history, and observability data remain available.
