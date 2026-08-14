locals {
  guild_solutions_ref = "b6050e5e4275e05303a769b3688088ac509449c2"
  model_names         = compact(var.existing_model_names)
  available_models    = toset([for model in data.sg_guild_models.existing.models : model.name])
  policies_by_name    = { for policy in data.sg_policies.existing.policies : policy.name => policy.id }
  policy_ids = {
    dangerous_ops = lookup(local.policies_by_name, "dangerous-ops", "")
    data_risk_pii = lookup(local.policies_by_name, "data-risk-pii", "")
  }

  github_integration_name  = data.sg_guild_integration.github.name
  grafana_integration_name = data.sg_guild_integration.grafana.name
  aws_integration_name     = data.sg_guild_integration.aws.name
  remote_runner_name       = data.sg_remote_runner.demo.name

  agent_names = {
    bootstrap  = "security-control-operator${var.name_suffix}"
    pr_review  = "security-evidence-analyst${var.name_suffix}"
    postdeploy = "postdeploy-assessor${var.name_suffix}"
  }
}

data "sg_guild_models" "existing" {}
data "sg_policies" "existing" {}

data "sg_guild_integration" "github" {
  name = var.github_integration_name
}

data "sg_guild_integration" "grafana" {
  name = var.grafana_integration_name
}

data "sg_guild_integration" "aws" {
  name = var.aws_integration_name
}

data "sg_remote_runner" "demo" {
  name = var.remote_runner_name
}

resource "terraform_data" "prerequisites" {
  lifecycle {
    precondition {
      condition     = length(local.model_names) > 0
      error_message = "At least one existing_model_names entry is required."
    }
    precondition {
      condition     = alltrue([for name in local.model_names : contains(local.available_models, name)])
      error_message = "Every requested model must already exist in the resolved workspace."
    }
    precondition {
      condition = (
        data.sg_guild_integration.github.type == "github" && data.sg_guild_integration.github.enabled &&
        data.sg_guild_integration.grafana.type == "grafana" && data.sg_guild_integration.grafana.enabled &&
        data.sg_guild_integration.aws.type == "aws" && data.sg_guild_integration.aws.enabled
      )
      error_message = "The selected existing GitHub, Grafana, and AWS integrations must have the expected type and be enabled."
    }
    precondition {
      condition     = local.policy_ids.dangerous_ops != "" && local.policy_ids.data_risk_pii != ""
      error_message = "Existing dangerous-ops and data-risk-pii policies are required."
    }
    precondition {
      condition     = data.sg_remote_runner.demo.status == "online"
      error_message = "The selected existing remote runner must be online."
    }
  }
}

module "supply_chain_security" {
  count  = var.enable_reference_agent_modules ? 1 : 0
  source = "github.com/appcd-dev/solutions//modules/aios-agent-supply-chain-security?ref=b6050e5e4275e05303a769b3688088ac509449c2"

  model_names                      = local.model_names
  policy_ids                       = { dangerous_ops = local.policy_ids.dangerous_ops }
  existing_github_integration_name = local.github_integration_name
  enable_cce                       = false
  enable_cce_reachability          = false
  name_suffix                      = trimprefix(var.name_suffix, "-")
  agent_budget                     = var.daily_agent_budget_usd
}

module "grafana_sre" {
  count  = var.enable_reference_agent_modules ? 1 : 0
  source = "github.com/appcd-dev/solutions//modules/aios-agent-grafana-sre?ref=b6050e5e4275e05303a769b3688088ac509449c2"

  model_names                       = local.model_names
  policy_ids                        = { dangerous_ops = local.policy_ids.dangerous_ops, data_risk_pii = local.policy_ids.data_risk_pii }
  grafana_secret_id                 = ""
  existing_grafana_integration_name = local.grafana_integration_name
  name_suffix                       = trimprefix(var.name_suffix, "-")
  agent_budget                      = var.daily_agent_budget_usd
}

resource "sg_agent" "bootstrap" {
  name        = local.agent_names.bootstrap
  persona     = templatefile("${path.module}/personas/security-control-operator.md.tftpl", { repository = var.repository_full_name, github_app_login = var.github_app_login, default_branch = var.default_branch })
  model_names = local.model_names
  integrations = [
    local.github_integration_name,
  ]
  hitl = { always_allowed = ["note", "read_notes"] }
  auto_approve_tools = [
    { tool = "${local.github_integration_name}_execute_command" },
    { tool = "${local.github_integration_name}_execute_series" },
  ]

  depends_on = [terraform_data.prerequisites]
}

resource "sg_agent" "pr_review" {
  name        = local.agent_names.pr_review
  persona     = templatefile("${path.module}/personas/security-evidence-analyst.md.tftpl", { repository = var.repository_full_name })
  model_names = local.model_names
  integrations = [
    local.github_integration_name,
    local.grafana_integration_name,
  ]
  hitl = { always_allowed = ["note", "read_notes"] }
  auto_approve_tools = [
    { tool = "${local.github_integration_name}_execute_series" },
  ]

  depends_on = [terraform_data.prerequisites]
}

resource "sg_agent" "postdeploy" {
  name        = local.agent_names.postdeploy
  persona     = templatefile("${path.module}/personas/postdeploy-assessor.md.tftpl", { repository = var.repository_full_name })
  model_names = local.model_names
  integrations = [
    local.github_integration_name,
    local.aws_integration_name,
    local.grafana_integration_name,
  ]
  remote_runners = [local.remote_runner_name]
  hitl           = { always_allowed = ["note", "read_notes"] }
  auto_approve_tools = [
    { tool = "${local.github_integration_name}_execute_series" },
    { tool = "${local.remote_runner_name}_execute_command" },
  ]

  depends_on = [terraform_data.prerequisites]
}

resource "sg_agent_budget" "custom" {
  for_each = local.agent_names

  agent_name  = each.value
  limit_usd   = var.daily_agent_budget_usd
  period_type = "daily"

  depends_on = [sg_agent.bootstrap, sg_agent.pr_review, sg_agent.postdeploy]
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  for_each = {
    bootstrap  = sg_agent.bootstrap.name
    pr_review  = sg_agent.pr_review.name
    postdeploy = sg_agent.postdeploy.name
  }

  agent_name = each.value
  policy_id  = local.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "postdeploy_data_risk" {
  agent_name = sg_agent.postdeploy.name
  policy_id  = local.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_runbook_sop" "bootstrap" {
  name        = "security-control-bootstrap${var.name_suffix}"
  approve     = true
  description = templatefile("${path.module}/runbooks/security-control-bootstrap.md.tftpl", { repository = var.repository_full_name, github_app_login = var.github_app_login, default_branch = var.default_branch })
}

resource "sg_runbook_sop" "pr_review" {
  name        = "pr-security-review${var.name_suffix}"
  approve     = true
  description = file("${path.module}/runbooks/pr-security-review.md")
}

resource "sg_runbook_sop" "postdeploy" {
  name        = "postdeploy-adversarial-assurance${var.name_suffix}"
  approve     = true
  description = file("${path.module}/runbooks/postdeploy-adversarial-assurance.md")
}

resource "sg_workflow" "bootstrap" {
  name        = "security-control-bootstrap${var.name_suffix}"
  domain      = "security"
  description = "Install missing deterministic PR security controls through one tightly constrained, automatically merged controls PR; when the control is already present, continue through required-check configuration, the audit comment, and the application-branch update."
  approve     = true

  required_inputs = ["repository_full_name", "pull_request_number", "head_sha"]
  runbook_refs    = [sg_runbook_sop.bootstrap.name]
  example_queries = ["Bootstrap security controls for the allowlisted application PR."]

  stages = [
    { stage_id = "validate-scope", description = "Validate repository, application PR, author, base branch, and captured head SHA.", required = true },
    { stage_id = "inventory-controls", description = "Inventory active workflows and required checks.", required = true },
    { stage_id = "open-controls-pr", description = "Copy reviewed templates and open one security-controls PR only when the control is absent. When it is already present, record the verified main commit and continue; do not end the workflow.", required = true },
    { stage_id = "validate-controls-pr", description = "Verify identity, base, prefix, paths, digests, file types, checks, and unchanged head SHA only for a controls PR. With an existing main control, record this stage as safely not required and continue; do not end the workflow.", required = true },
    { stage_id = "merge-controls-pr", description = "Auto-merge only the validated controls PR without submitting an approval. With an existing main control, record no merge required and continue to configure-gate; do not end the workflow.", required = true },
    { stage_id = "configure-gate", description = "Create or verify the dedicated security-gate ruleset when repository administration is available; record a permission or plan limitation and continue otherwise. This cannot end the workflow before the application branch is advanced.", required = true },
    { stage_id = "comment-application-pr", description = "Comment on the original PR with an exact audit summary using gh pr comment --body-file, never --body @path, even when ruleset administration is unavailable.", required = true },
    { stage_id = "update-application-branch", description = "Update the original branch with expected_head_sha compare-and-swap after the audit comment. A genuine conflict or concurrent-head mismatch must be commented explicitly.", required = true },
    { stage_id = "verify-security-run", description = "Require a new application SHA and started Security gate workflow before completing; do not finish after controls merge alone.", required = true },
  ]

  stage_bindings = [
    { stage_id = "validate-scope", agent_ref = sg_agent.bootstrap.name, runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "inventory-controls", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["validate-scope"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "open-controls-pr", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["inventory-controls"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "validate-controls-pr", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["open-controls-pr"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "merge-controls-pr", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["validate-controls-pr"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "configure-gate", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["merge-controls-pr"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "comment-application-pr", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["configure-gate"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "update-application-branch", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["comment-application-pr"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
    { stage_id = "verify-security-run", agent_ref = sg_agent.bootstrap.name, stage_depends_on = ["update-application-branch"], runbook_refs = [sg_runbook_sop.bootstrap.name], skill_refs = [sg_runbook_sop.bootstrap.name] },
  ]
}

resource "sg_workflow" "pr_review" {
  name        = "pr-security-review${var.name_suffix}"
  domain      = "security"
  description = "Correlate completed deterministic PR evidence and publish one redacted review comment without changing the security gate."
  approve     = true

  required_inputs = ["repository_full_name", "pull_request_number", "workflow_run_id", "commit_sha"]
  runbook_refs    = [sg_runbook_sop.pr_review.name]

  stages = [
    { stage_id = "validate-scope", description = "Validate repository, PR, workflow run, and latest SHA.", required = true },
    { stage_id = "collect-evidence", description = "Read all scanner conclusions and artifacts.", required = true },
    { stage_id = "correlate-findings", description = "Deduplicate and classify blocking versus advisory findings.", required = true },
    { stage_id = "publish-review", description = "Post one concise redacted PR comment.", required = true },
  ]

  stage_bindings = [
    { stage_id = "validate-scope", agent_ref = sg_agent.pr_review.name, runbook_refs = [sg_runbook_sop.pr_review.name], skill_refs = [sg_runbook_sop.pr_review.name] },
    { stage_id = "collect-evidence", agent_ref = sg_agent.pr_review.name, stage_depends_on = ["validate-scope"], runbook_refs = [sg_runbook_sop.pr_review.name], skill_refs = [sg_runbook_sop.pr_review.name] },
    { stage_id = "correlate-findings", agent_ref = sg_agent.pr_review.name, stage_depends_on = ["collect-evidence"], runbook_refs = [sg_runbook_sop.pr_review.name], skill_refs = [sg_runbook_sop.pr_review.name] },
    { stage_id = "publish-review", agent_ref = sg_agent.pr_review.name, stage_depends_on = ["correlate-findings"], runbook_refs = [sg_runbook_sop.pr_review.name], skill_refs = [sg_runbook_sop.pr_review.name] },
  ]
}

resource "sg_workflow" "postdeploy" {
  name        = "postdeploy-adversarial-assurance${var.name_suffix}"
  domain      = "security"
  description = "Correlate bounded post-deployment AWS, network, application, and observability evidence and publish compliance status."
  approve     = true

  required_inputs = ["repository_full_name", "commit_sha", "image_digest", "coolify_deployment_uuid", "target_url", "aws_region", "demo_run_id", "evidence_run_id", "report_location"]
  runbook_refs    = [sg_runbook_sop.postdeploy.name]

  stages = [
    { stage_id = "validate-scope", description = "Validate allowlisted host, repository, deployment identity, and immutable image digest.", required = true },
    { stage_id = "read-aws-posture", description = "Read ALB, WAF, TLS, ingress, egress, and EC2 management exposure evidence.", required = true },
    { stage_id = "read-active-scan-evidence", description = "Read Nmap, ZAP, authentication, header, and TLS artifacts.", required = true },
    { stage_id = "bounded-follow-up", description = "Run only justified allowlisted non-destructive HTTP probes.", required = true },
    { stage_id = "correlate-observability", description = "Confirm demo_run_id in VictoriaMetrics, Loki, and Jaeger and validate OpsVerse health.", required = true },
    { stage_id = "evaluate-controls", description = "Evaluate the deterministic policy decision and explain failures without overriding it.", required = true },
    { stage_id = "publish-assessment", description = "Publish one redacted compliance assessment with evidence links.", required = true },
  ]

  stage_bindings = [
    { stage_id = "validate-scope", agent_ref = sg_agent.postdeploy.name, runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "read-aws-posture", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["validate-scope"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "read-active-scan-evidence", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["validate-scope"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "bounded-follow-up", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["read-active-scan-evidence"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "correlate-observability", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["read-aws-posture", "bounded-follow-up"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "evaluate-controls", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["correlate-observability"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
    { stage_id = "publish-assessment", agent_ref = sg_agent.postdeploy.name, stage_depends_on = ["evaluate-controls"], runbook_refs = [sg_runbook_sop.postdeploy.name], skill_refs = [sg_runbook_sop.postdeploy.name] },
  ]
}

resource "sg_webhook" "bootstrap" {
  name           = "security-control-bootstrap${var.name_suffix}"
  target_type    = "workflow"
  target_name    = sg_workflow.bootstrap.name
  action         = "A same-repository application PR opened. Validate scope and bootstrap only the reviewed deterministic security controls."
  enabled        = true
  allowed_cidrs  = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
  token_rotation = "v1"
}

resource "sg_webhook" "pr_review" {
  name           = "pr-security-review${var.name_suffix}"
  target_type    = "workflow"
  target_name    = sg_workflow.pr_review.name
  action         = "A deterministic PR security workflow completed. Correlate its evidence and publish one review without changing the gate conclusion."
  enabled        = true
  allowed_cidrs  = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
  token_rotation = "v1"
}

resource "sg_webhook" "postdeploy" {
  name           = "postdeploy-adversarial-assurance${var.name_suffix}"
  target_type    = "workflow"
  target_name    = sg_workflow.postdeploy.name
  action         = "A successful Coolify redeployment produced bounded security evidence. Correlate it and publish a redacted compliance assessment."
  enabled        = true
  allowed_cidrs  = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
  token_rotation = "v1"
}
