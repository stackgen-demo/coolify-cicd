# AWS and Coolify infrastructure

This root creates a dedicated VPC, internet-facing ALB, TLS redirect/listeners, WAF header validation, an SSM-managed EC2 host, narrowly scoped security groups, and an encrypted evidence bucket. EC2 exposes only application port `3000` to the ALB security group. SSH and Coolify port `8000` are not public; use the `ssm_coolify_port_forward_command` output.

The EC2 bootstrap installs Coolify and the OpsVerse agent. Store a rotated OpsVerse token in an existing AWS Secrets Manager secret and pass only its ARN. Never put the token in tfvars.

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
