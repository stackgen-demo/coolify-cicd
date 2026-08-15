variable "stackgen_url" {
  description = "Aiden/StackGen base URL."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen PAT. Supply through TF_VAR_stackgen_token."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Resolved workspace UUID, never the display name."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.stackgen_project_id))
    error_message = "stackgen_project_id must be a UUID resolved from the human workspace name."
  }
}

variable "existing_model_names" {
  description = "Existing Guild model names to reuse."
  type        = list(string)
  default     = ["openai-se-workspace-gpt-5.6-terra-tool-calling"]
}

variable "repository_full_name" {
  description = "Single allowlisted GitHub repository in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository_full_name))
    error_message = "repository_full_name must use owner/name form."
  }
}

variable "github_app_login" {
  description = "Dedicated GitHub App bot login authorized for the security-controls exception."
  type        = string
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "name_suffix" {
  description = "Stable collision-avoidance suffix."
  type        = string
  default     = "-talkdesk-demo"

  validation {
    condition     = can(regex("^-[a-z0-9-]+$", var.name_suffix))
    error_message = "name_suffix must start with a hyphen and contain lowercase letters, digits, and hyphens."
  }
}

variable "github_integration_name" {
  type    = string
  default = "github-integration"
}

variable "remote_runner_name" {
  type    = string
  default = "demo-runner"
}

variable "grafana_integration_name" {
  type    = string
  default = "sandbox-grafana"
}

variable "aws_integration_name" {
  type    = string
  default = "stackgen-sandbox"
}

variable "linear_integration_name" {
  description = "Existing enabled Linear integration used to create the post-assessment SOC 2 ticket."
  type        = string
  default     = "devops-linear"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "direct_pentest_target_url" {
  description = "Exact HTTPS URL allowlisted for the expedited direct post-deployment assessment."
  type        = string
  default     = "https://talkdesk-coolify.demo.stackgen.com"

  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+(?::[0-9]+)?/?$", var.direct_pentest_target_url))
    error_message = "direct_pentest_target_url must be one exact HTTPS origin without a path, query, or fragment."
  }
}

variable "direct_pentest_alb_arn" {
  description = "Exact demo ALB ARN allowlisted for direct AWS posture reads."
  type        = string
  default     = "arn:aws:elasticloadbalancing:us-east-1:180217099948:loadbalancer/app/talkdesk-coolify-demo/3f4b3a514b72ef3a"
}

variable "direct_pentest_alb_security_group_id" {
  description = "Exact demo ALB security group allowlisted for direct ingress and egress reads."
  type        = string
  default     = "sg-00e3a0823d9d6f8ca"
}

variable "direct_pentest_ec2_security_group_id" {
  description = "Exact demo EC2 security group allowlisted for direct ingress and egress reads."
  type        = string
  default     = "sg-093fe8005fedfdb46"
}

variable "direct_pentest_waf_header_name" {
  description = "Non-secret demo header name required by WAF on /api paths."
  type        = string
  default     = "x-demo-client"
}

variable "direct_pentest_waf_header_value" {
  description = "Non-secret demo header value accepted by WAF on /api paths."
  type        = string
  default     = "talkdesk-security-demo"
}

variable "webhook_allowed_cidrs" {
  description = "Optional ingress CIDRs for Aiden webhooks. Empty uses platform authentication only."
  type        = list(string)
  default     = []
}

variable "webhook_trigger_base_url" {
  description = "StackGen base URL used to compose webhook trigger endpoints."
  type        = string
  default     = ""
}

variable "daily_agent_budget_usd" {
  type    = number
  default = 20
}

variable "enable_reference_agent_modules" {
  description = "Also deploy the reusable supply-chain and Grafana SRE agents."
  type        = bool
  default     = true
}
