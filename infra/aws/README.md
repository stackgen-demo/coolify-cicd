# AWS and Coolify infrastructure

This root creates a dedicated VPC, internet-facing ALB, TLS redirect/listeners, WAF header validation, an SSM-managed EC2 host, narrowly scoped security groups, and an encrypted evidence bucket. EC2 exposes only application port `3000` to the ALB security group. SSH and Coolify port `8000` are not public; use the `ssm_coolify_port_forward_command` output.

The EC2 bootstrap installs Coolify and the OpsVerse agent. Store the OpsVerse token in an existing AWS Secrets Manager secret and pass only its ARN. Never put the token in tfvars.

Coolify's management API remains private on the EC2 host. GitHub Actions never connects to port 8000 and never receives the Coolify API token. The deployment workflow assumes its OIDC role, uses SSM to invoke the host-local Coolify API helper, and receives only a deployment UUID. Store the Coolify API token in a second Secrets Manager secret and pass its ARN as `coolify_api_secret_arn`.

Both remotely downloaded installers are checksum-pinned. Re-download and review an installer before intentionally changing its SHA-256 variable; a changed upstream script must fail closed during bootstrap.

If the AWS account already has the GitHub Actions OIDC provider, set `github_repository` and `github_oidc_provider_arn`. The root then creates a repository-scoped read-only role for the post-deployment evidence workflow; copy its output to the `POSTDEPLOY_AWS_ROLE_ARN` repository variable.

```bash
tofu init
tofu fmt -check -recursive
tofu validate
tofu plan -out=tfplan
tofu show -json tfplan | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
```

Do not apply a plan containing deletes or replacements without explicit review.

## First deployment sequence

This root has not been applied in the current AWS account. Complete the following sequence with real values; do not create placeholder resources or commit a `terraform.tfvars` file.

1. Create or select the ACM certificate for `domain_name`, Route53 zone (when managed here), the GitHub OIDC provider, and two Secrets Manager secrets: one for the OpsVerse token and one placeholder for the Coolify API token.
2. Copy `terraform.tfvars.example` outside the repository, set the certificate/domain/OIDC/secret ARNs and installer checksums, then run a saved OpenTofu plan and reject deletes or replacements before applying.
3. After SSM reports the host is online, start the output `ssm_coolify_port_forward_command`. Complete Coolify's one-time onboarding at `http://127.0.0.1:8000`, create a least-privilege API token, and replace the placeholder value in the Coolify token secret. Do not expose port 8000.
4. Dispatch `Publish immutable demo artifact` and copy its `ghcr.io/...@sha256:...` output. Do not use a mutable tag as `DEMO_IMAGE_REFERENCE` or `DEMO_IMAGE_DIGEST`.
5. With the SSM tunnel active, run `scripts/coolify/configure-demo-application.sh` from the repository root. It creates or reuses the Docker Compose application, installs its runtime environment, and prints `COOLIFY_APPLICATION_UUID` without printing secret values.
6. Configure the repository variables and secrets listed below. The next merged `demo-application` PR invokes Coolify through SSM, waits for the deployment, collects evidence, and invokes Aiden post-deployment assurance.

## GitHub Actions configuration

Set these repository variables from the applied Terraform outputs or the selected runtime configuration:

| Variable | Source |
| --- | --- |
| `AWS_REGION` | Terraform input `aws_region` |
| `COOLIFY_APPLICATION_UUID` | `configure-demo-application.sh` output |
| `COOLIFY_INSTANCE_ID` | `coolify_instance_id` output |
| `DEMO_IMAGE_DIGEST` | Immutable image reference from the publish workflow |
| `EVIDENCE_BUCKET` | `evidence_bucket` output |
| `DEMO_TARGET_URL` / `DEMO_ALLOWED_HOST` | `application_url` / hostname |
| `POSTDEPLOY_AWS_ROLE_ARN` | `github_postdeploy_role_arn` output |
| `ALB_ARN` / `ALB_SECURITY_GROUP_ID` / `EC2_SECURITY_GROUP_ID` | matching Terraform outputs |
| `WAF_HEADER_NAME` / `WAF_HEADER_VALUE` | Terraform input values |
| `AUTH_ISSUER` / `AUTH_AUDIENCE` | application runtime configuration |
| `GRAFANA_URL` / `JAEGER_DATASOURCE_UID` / `LOKI_URL` / `VICTORIA_METRICS_QUERY_URL` / `OPSVERSE_METRIC_QUERY` | ObserveNow configuration |

Set these repository secrets (never variables or committed files): `AUTH_HS256_SECRET`, `GRAFANA_READER_TOKEN`, `OBSERVENOW_USERNAME`, and `OBSERVENOW_PASSWORD`. The Aiden webhook secrets are already managed separately. Coolify's API token stays in AWS Secrets Manager only.
