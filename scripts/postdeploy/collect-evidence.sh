#!/usr/bin/env bash
set -euo pipefail

: "${ALB_ARN:?ALB_ARN is required}"
: "${ALB_SECURITY_GROUP_ID:?ALB_SECURITY_GROUP_ID is required}"
: "${ALLOWED_HOST:?ALLOWED_HOST is required}"
: "${AWS_REGION:?AWS_REGION is required}"
: "${DEMO_RUN_ID:?DEMO_RUN_ID is required}"
: "${EC2_SECURITY_GROUP_ID:?EC2_SECURITY_GROUP_ID is required}"
: "${TARGET_URL:?TARGET_URL is required}"
: "${WAF_HEADER_NAME:?WAF_HEADER_NAME is required}"
: "${WAF_HEADER_VALUE:?WAF_HEADER_VALUE is required}"

target_host="$(node -e 'const u=new URL(process.argv[1]); process.stdout.write(u.hostname)' "${TARGET_URL}")"
if [[ "${target_host}" != "${ALLOWED_HOST}" ]]; then
  echo "Target host is outside the explicit allowlist" >&2
  exit 1
fi

mkdir -p evidence/network evidence/aws evidence/http

nmap --host-timeout 3m --max-retries 2 -Pn -sT -p 1-1024,3000,8000,8080,8443 \
  -oX evidence/network/nmap.xml "${target_host}" >/dev/null
python3 - <<'PY'
import json
import xml.etree.ElementTree as ET
root = ET.parse("evidence/network/nmap.xml").getroot()
ports = sorted({int(node.attrib["portid"]) for node in root.findall(".//port") if node.find("state").attrib.get("state") == "open"})
with open("evidence/network/ports.json", "w", encoding="utf-8") as stream:
    json.dump({"open_ports": ports}, stream, indent=2)
    stream.write("\n")
PY

http_code="$(curl --silent --output /dev/null --write-out '%{http_code}' "http://${target_host}/healthz")"
redirect_url="$(curl --silent --output /dev/null --write-out '%{redirect_url}' "http://${target_host}/healthz")"
https_code="$(curl --silent --output /dev/null --write-out '%{http_code}' "${TARGET_URL%/}/healthz")"
tls_valid=false
if openssl s_client -connect "${target_host}:443" -servername "${target_host}" -verify_return_error </dev/null >/dev/null 2>&1; then tls_valid=true; fi
jq -n --arg http_code "${http_code}" --arg redirect_url "${redirect_url}" --arg https_code "${https_code}" --argjson tls_valid "${tls_valid}" \
  '{http_code:($http_code|tonumber),redirect_url:$redirect_url,https_code:($https_code|tonumber),redirect_enforced:($redirect_url|startswith("https://")),tls_valid:$tls_valid}' \
  > evidence/http/https.json

missing_code="$(curl --silent --output /dev/null --write-out '%{http_code}' "${TARGET_URL%/}/api/public")"
malformed_code="$(curl --silent --output /dev/null --write-out '%{http_code}' --header "${WAF_HEADER_NAME}: invalid" "${TARGET_URL%/}/api/public")"
valid_code="$(curl --silent --output /dev/null --write-out '%{http_code}' --header "${WAF_HEADER_NAME}: ${WAF_HEADER_VALUE}" --header "X-Demo-Run-Id: ${DEMO_RUN_ID}" "${TARGET_URL%/}/api/public")"
jq -n --arg missing "${missing_code}" --arg malformed "${malformed_code}" --arg valid "${valid_code}" \
  '{missing_status:($missing|tonumber),malformed_status:($malformed|tonumber),valid_status:($valid|tonumber),missing_header_blocked:($missing=="403"),malformed_header_blocked:($malformed=="403"),valid_header_allowed:($valid=="200")}' \
  > evidence/http/waf.json

aws ec2 describe-security-groups --region "${AWS_REGION}" \
  --group-ids "${ALB_SECURITY_GROUP_ID}" "${EC2_SECURITY_GROUP_ID}" \
  > evidence/aws/security-groups.json
aws elbv2 describe-listeners --region "${AWS_REGION}" --load-balancer-arn "${ALB_ARN}" > evidence/aws/listeners.json
aws wafv2 get-web-acl-for-resource --region "${AWS_REGION}" --resource-arn "${ALB_ARN}" > evidence/aws/waf.json
