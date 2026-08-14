output "alb_arn" {
  value = aws_lb.demo.arn
}

output "application_url" {
  value = "https://${var.domain_name}"
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "coolify_instance_id" {
  value = aws_instance.coolify.id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "evidence_bucket" {
  value = aws_s3_bucket.evidence.id
}

output "evidence_prefix" {
  value = "s3://${aws_s3_bucket.evidence.id}/runs"
}

output "github_postdeploy_role_arn" {
  description = "Set this as the POSTDEPLOY_AWS_ROLE_ARN GitHub Actions variable."
  value       = try(aws_iam_role.github_postdeploy[0].arn, null)
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.demo.arn
}

output "ssm_coolify_port_forward_command" {
  description = "Use SSM instead of exposing Coolify's management port."
  value       = "aws ssm start-session --target ${aws_instance.coolify.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8000\"],\"localPortNumber\":[\"8000\"]}' --region ${var.aws_region}"
}
