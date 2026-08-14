# Aiden Resource Patterns

Use these patterns only after checking the installed provider schema and current Guild-Solutions module contracts.

## Provider and Root

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url      = var.stackgen_url
  stackgen_token    = var.stackgen_token
  project_id        = var.stackgen_project_id
  adopt_on_conflict = true
}
```

Mark `stackgen_token` sensitive. Pass the resolved UUID to `stackgen_project_id`.

## Layered Module Composition

```hcl
module "foundation" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation?ref=<pinned-tag-or-commit>"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
  llm_api_keys   = var.llm_api_keys
}

module "policies" {
  source = "github.com/appcd-dev/solutions//modules/aios-policies?ref=<same-pin>"
}
```

Pass `module.foundation.model_names` and only the policy keys required by each agent module. Do not use an unpinned `main` reference outside local development.

## Existing Integrations

Prefer `existing_*_integration_name` or `existing_secret_id` variables. A root may provision an integration only when it owns the credential reference and the module contract supports it.

Grafana provisioning and Aiden querying should use separate service accounts:

- Terraform provisioner: dashboards/folders/alert rules write access.
- Aiden reader: datasource, dashboard, and alert read access.

Do not put either token directly in HCL.

## Custom Agent

```hcl
resource "sg_agent" "security_guardian" {
  name        = "security-guardian${local.suffix}"
  persona     = file("${path.module}/personas/security-guardian.md")
  model_names = compact(module.foundation.model_names)
  integrations = compact([
    var.existing_github_integration_name,
    var.existing_ubuntu_integration_name,
    var.existing_grafana_integration_name,
  ])
}

resource "sg_agent_budget" "security_guardian" {
  agent_name  = sg_agent.security_guardian.name
  limit_usd   = 20
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.security_guardian.name
  policy_id  = module.policies.policy_ids.dangerous_ops
  enabled    = true
}
```

Keep the persona in a file. State scope, allowed targets, prohibited actions, evidence format, and escalation behavior.

## Runbook and Workflow

```hcl
resource "sg_runbook_sop" "review" {
  name        = "security-review${local.suffix}"
  approve     = true
  description = file("${path.module}/runbooks/security-review.md")
}

resource "sg_workflow" "review" {
  name        = "pr-security-review${local.suffix}"
  domain      = "security"
  description = "Correlate deterministic PR scan evidence and publish a bounded review."
  approve     = true

  required_inputs = ["repository_full_name", "pull_request_number", "workflow_run_id", "commit_sha"]

  stages = [
    { stage_id = "validate-scope", description = "Validate repository, PR, commit, and run identity.", required = true },
    { stage_id = "collect-evidence", description = "Read scanner conclusions and artifacts.", required = true },
    { stage_id = "correlate-findings", description = "Deduplicate and prioritize findings.", required = true },
    { stage_id = "publish-review", description = "Post one redacted PR review comment.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "validate-scope"
      agent_ref    = sg_agent.security_guardian.name
      runbook_refs = [sg_runbook_sop.review.name]
      skill_refs   = [sg_runbook_sop.review.name]
    },
    {
      stage_id         = "collect-evidence"
      agent_ref        = sg_agent.security_guardian.name
      stage_depends_on = ["validate-scope"]
      runbook_refs     = [sg_runbook_sop.review.name]
      skill_refs       = [sg_runbook_sop.review.name]
    },
    {
      stage_id         = "correlate-findings"
      agent_ref        = sg_agent.security_guardian.name
      stage_depends_on = ["collect-evidence"]
      runbook_refs     = [sg_runbook_sop.review.name]
      skill_refs       = [sg_runbook_sop.review.name]
    },
    {
      stage_id         = "publish-review"
      agent_ref        = sg_agent.security_guardian.name
      stage_depends_on = ["correlate-findings"]
      runbook_refs     = [sg_runbook_sop.review.name]
      skill_refs       = [sg_runbook_sop.review.name]
    },
  ]
}
```

Every binding must reference an existing stage ID. Encode dependencies explicitly. Keep one final publisher stage to avoid duplicate comments.

Use deterministic `evidence_gate` or `conditional_skip` action stages for policy decisions. Do not ask an LLM to replace Gitleaks, Semgrep, Trivy, OPA, or a branch protection check.

## Webhook

```hcl
resource "sg_webhook" "review" {
  name           = "pr-security-review${local.suffix}"
  target_type    = "workflow"
  target_name    = sg_workflow.review.name
  action         = "A completed PR security workflow supplied normalized evidence. Validate scope, correlate findings, and publish one review."
  enabled        = true
  token_rotation = "v1"
}
```

Treat the webhook token as sensitive. Prefer a GitHub Actions repository secret. Trigger review after deterministic scan jobs finish so the agent does not race incomplete results.

## Schedule

```hcl
module "schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules?ref=<same-pin>"

  target_type = "workflow"
  target_name = sg_workflow.review.name
  schedules = [{
    name       = "weekly-security-review"
    expression = "0 9 * * 1"
    action     = "Run the bounded weekly security review for the configured repository."
  }]
}
```

Use schedules for recurring evidence or drift checks, not for deployment unless explicitly requested.

## Outputs

```hcl
output "workflow_names" {
  value = {
    pr_review = sg_workflow.review.name
  }
}

output "review_webhook_token" {
  value     = sg_webhook.review.token
  sensitive = true
}
```

Expose names and non-secret endpoints normally. Mark tokens and credential-bearing URLs sensitive.

## Plan Audit

Accepted actions are expected `create`, `update`, or `no-op`. Stop for:

- `delete`
- `delete,create`
- provider or project UUID changes
- unrelated module changes
- duplicate names already owned by another state
