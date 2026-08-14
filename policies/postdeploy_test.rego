package talkdesk.postdeploy_test

import rego.v1

valid_input := {
  "demo_run_id": "run-1",
  "image_digest": "sha256:abc",
  "source_commit_sha": "abc",
  "network": {"open_ports": [80, 443]},
  "https": {"redirect_enforced": true, "tls_valid": true},
  "waf": {"missing_header_blocked": true, "malformed_header_blocked": true, "valid_header_allowed": true},
  "aws": {"waf_attached": true, "alb_ingress_restricted": true, "alb_egress_restricted": true, "ingress_from_alb_only": true, "egress_restricted": true, "management_port_public": false},
  "authentication": {"missing": 401, "malformed": 401, "expired": 401, "wrong_signature": 401, "wrong_audience": 401},
  "collectors": {"application_otel_healthy": true, "opsverse_agent_healthy": true},
  "observability": {"correlation_complete": true},
}

test_valid_postdeploy_allows if data.talkdesk.postdeploy.allow with input as valid_input

test_open_ssh_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"network": {"open_ports": [22, 80, 443]}})
  not result.allow
  "unexpected public port" in result.deny
}

test_wrong_audience_must_be_rejected if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"authentication": object.union(valid_input.authentication, {"wrong_audience": 200})})
  not result.allow
}

test_unrestricted_egress_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"aws": object.union(valid_input.aws, {"egress_restricted": false})})
  not result.allow
  "EC2 egress exceeds documented HTTPS and DNS rules" in result.deny
}

test_unrestricted_alb_ingress_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"aws": object.union(valid_input.aws, {"alb_ingress_restricted": false})})
  not result.allow
}

test_unrestricted_alb_egress_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"aws": object.union(valid_input.aws, {"alb_egress_restricted": false})})
  not result.allow
}

test_non_alb_ingress_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"aws": object.union(valid_input.aws, {"ingress_from_alb_only": false})})
  not result.allow
}

test_missing_waf_header_block_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"waf": object.union(valid_input.waf, {"missing_header_blocked": false})})
  not result.allow
}

test_http_without_https_redirect_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"https": object.union(valid_input.https, {"redirect_enforced": false})})
  not result.allow
}

test_missing_telemetry_correlation_denies if {
  result := data.talkdesk.postdeploy.decision with input as object.union(valid_input, {"observability": {"correlation_complete": false}})
  not result.allow
}
