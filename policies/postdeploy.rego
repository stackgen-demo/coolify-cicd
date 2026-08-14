package talkdesk.postdeploy

import rego.v1

default allow := false

required_auth_cases := {"missing", "malformed", "expired", "wrong_signature", "wrong_audience"}

deny contains "unexpected public port" if {
  some port in input.network.open_ports
  not port in {80, 443}
}

deny contains "HTTP does not redirect to HTTPS" if not input.https.redirect_enforced
deny contains "TLS validation failed" if not input.https.tls_valid
deny contains "WAF is not attached" if not input.aws.waf_attached
deny contains "WAF accepted a missing required header" if not input.waf.missing_header_blocked
deny contains "WAF accepted a malformed required header" if not input.waf.malformed_header_blocked
deny contains "WAF rejected the valid required header" if not input.waf.valid_header_allowed
deny contains "ALB ingress exposes ports other than HTTP and HTTPS" if not input.aws.alb_ingress_restricted
deny contains "ALB egress is not restricted to the EC2 application port" if not input.aws.alb_egress_restricted
deny contains "EC2 application ingress is not restricted to the ALB security group" if not input.aws.ingress_from_alb_only
deny contains "EC2 egress exceeds documented HTTPS and DNS rules" if not input.aws.egress_restricted
deny contains "public SSH or Coolify management exposure detected" if input.aws.management_port_public
deny contains "application collector is unhealthy" if not input.collectors.application_otel_healthy
deny contains "infrastructure agent is unhealthy" if not input.collectors.opsverse_agent_healthy
deny contains "deployment correlation is missing from one or more telemetry backends" if not input.observability.correlation_complete

deny contains sprintf("authentication case %s was not rejected", [case]) if {
  some case in required_auth_cases
  input.authentication[case] != 401
}

allow if count(deny) == 0

decision := {
  "allow": allow,
  "deny": sort([reason | some reason in deny]),
  "demo_run_id": input.demo_run_id,
  "image_digest": input.image_digest,
  "source_commit_sha": input.source_commit_sha,
}
