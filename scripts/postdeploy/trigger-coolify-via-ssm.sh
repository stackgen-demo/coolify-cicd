#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${COOLIFY_APPLICATION_UUID:?COOLIFY_APPLICATION_UUID is required}"
: "${COOLIFY_INSTANCE_ID:?COOLIFY_INSTANCE_ID is required}"

if ! [[ "${COOLIFY_APPLICATION_UUID}" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "COOLIFY_APPLICATION_UUID is not a valid UUID-like value" >&2
  exit 64
fi

parameters="$(jq -cn --arg app_uuid "${COOLIFY_APPLICATION_UUID}" \
  '{commands:["sudo /usr/local/bin/talkdesk-coolify-deploy " + $app_uuid]}')"

command_id="$(aws ssm send-command \
  --region "${AWS_REGION}" \
  --document-name AWS-RunShellScript \
  --instance-ids "${COOLIFY_INSTANCE_ID}" \
  --parameters "${parameters}" \
  --query 'Command.CommandId' \
  --output text)"

deadline=$((SECONDS + 120))
while ((SECONDS < deadline)); do
  invocation="$(aws ssm get-command-invocation \
    --region "${AWS_REGION}" \
    --command-id "${command_id}" \
    --instance-id "${COOLIFY_INSTANCE_ID}" \
    --output json 2>/dev/null || true)"
  status="$(jq -r '.Status // "pending"' <<<"${invocation}")"
  case "${status}" in
    Success)
      deployment_uuid="$(jq -er '.StandardOutputContent | fromjson | .deployments[0].deployment_uuid // .deployment_uuid' <<<"${invocation}")"
      printf 'deployment_uuid=%s\n' "${deployment_uuid}" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
      exit 0
      ;;
    Cancelled|Cancelling|Failed|TimedOut)
      jq -r '.StandardErrorContent // empty' <<<"${invocation}" >&2
      exit 1
      ;;
  esac
  sleep 3
done

echo "Timed out waiting for the Coolify deployment command" >&2
exit 1
