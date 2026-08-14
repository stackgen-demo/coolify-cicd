locals {
  webhook_base_url = trimspace(var.webhook_trigger_base_url) == "" ? var.stackgen_url : var.webhook_trigger_base_url
  webhook_endpoint = "${trimsuffix(trimspace(local.webhook_base_url), "/")}/api/v1/webhooks/trigger"
}

output "agent_names" {
  value = local.agent_names
}

output "workflow_names" {
  value = {
    bootstrap  = sg_workflow.bootstrap.name
    pr_review  = sg_workflow.pr_review.name
    postdeploy = sg_workflow.postdeploy.name
  }
}

output "webhook_trigger_endpoint" {
  value = local.webhook_endpoint
}

output "webhook_tokens" {
  sensitive = true
  value = {
    bootstrap  = sg_webhook.bootstrap.token
    pr_review  = sg_webhook.pr_review.token
    postdeploy = sg_webhook.postdeploy.token
  }
}

output "webhook_payload_urls" {
  sensitive = true
  value = {
    bootstrap  = "${local.webhook_endpoint}?apiKey=${urlencode(sg_webhook.bootstrap.token)}&orgId=${urlencode(var.stackgen_project_id)}"
    pr_review  = "${local.webhook_endpoint}?apiKey=${urlencode(sg_webhook.pr_review.token)}&orgId=${urlencode(var.stackgen_project_id)}"
    postdeploy = "${local.webhook_endpoint}?apiKey=${urlencode(sg_webhook.postdeploy.token)}&orgId=${urlencode(var.stackgen_project_id)}"
  }
}

output "reused_workspace_resources" {
  value = {
    models              = local.model_names
    github_integration  = local.github_integration_name
    grafana_integration = local.grafana_integration_name
    aws_integration     = local.aws_integration_name
    remote_runner       = local.remote_runner_name
    policy_ids          = local.policy_ids
  }
}

output "reference_agent_names" {
  value = var.enable_reference_agent_modules ? {
    supply_chain = module.supply_chain_security[0].agent_name
    grafana_sre  = module.grafana_sre[0].agent_name
  } : {}
}
