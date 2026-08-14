variable "aws_region" {
  description = "AWS region for the demo infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Stable prefix for AWS resource names."
  type        = string
  default     = "talkdesk-coolify-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain lowercase letters, digits, and hyphens only."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated demo VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type used for Coolify and the demo application."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size_gib" {
  description = "Encrypted root volume size."
  type        = number
  default     = 60
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN for domain_name."
  type        = string
}

variable "domain_name" {
  description = "Public application hostname routed to the ALB."
  type        = string
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID. Leave empty to manage DNS elsewhere."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository in owner/name form. Set with github_oidc_provider_arn to create the post-deployment read role."
  type        = string
  default     = ""

  validation {
    condition     = var.github_repository == "" || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be empty or use owner/name form."
  }
}

variable "github_oidc_provider_arn" {
  description = "ARN of the account's existing token.actions.githubusercontent.com OIDC provider."
  type        = string
  default     = ""

  validation {
    condition = (
      var.github_oidc_provider_arn == "" ||
      can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.github_oidc_provider_arn))
    )
    error_message = "github_oidc_provider_arn must reference token.actions.githubusercontent.com."
  }
}

variable "github_actions_environment" {
  description = "GitHub environment allowed to assume the post-deployment evidence role."
  type        = string
  default     = "demo-deploy"
}

variable "waf_header_name" {
  description = "Lowercase request header that AWS WAF requires for /api paths."
  type        = string
  default     = "x-demo-client"
}

variable "waf_header_value" {
  description = "Non-secret expected value for the WAF demo header."
  type        = string
  default     = "talkdesk-security-demo"
}

variable "opsverse_agent_secret_arn" {
  description = "Existing AWS Secrets Manager secret ARN containing only the rotated OpsVerse agent token."
  type        = string
  sensitive   = true
}

variable "coolify_api_secret_arn" {
  description = "Existing AWS Secrets Manager secret ARN containing the post-onboarding Coolify API token used only by host-local SSM commands."
  type        = string
  sensitive   = true
}

variable "coolify_installer_sha256" {
  description = "Reviewed SHA-256 of the Coolify installer downloaded by EC2 bootstrap."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.coolify_installer_sha256))
    error_message = "coolify_installer_sha256 must be a lowercase SHA-256 digest."
  }
}

variable "opsverse_installer_sha256" {
  description = "Reviewed SHA-256 of the OpsVerse installer downloaded by EC2 bootstrap."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.opsverse_installer_sha256))
    error_message = "opsverse_installer_sha256 must be a lowercase SHA-256 digest."
  }
}

variable "opsverse_metrics_host" {
  type    = string
  default = "metrics-opsverse-demo-us.us-east4.gcp.opsverse.cloud"
}

variable "opsverse_logs_host" {
  type    = string
  default = "logs-opsverse-demo-us.us-east4.gcp.opsverse.cloud"
}

variable "opsverse_traces_host" {
  type    = string
  default = "traces-collector-opsverse-demo-us.us-east4.gcp.opsverse.cloud"
}

variable "evidence_retention_days" {
  description = "Retention for generated evidence bundles."
  type        = number
  default     = 30
}
