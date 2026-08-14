#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${COOLIFY_INSTANCE_ID:?COOLIFY_INSTANCE_ID is required}"
: "${DEPLOYMENT_UUID:?DEPLOYMENT_UUID is required}"

if ! [[ "${DEPLOYMENT_UUID}" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "DEPLOYMENT_UUID is not a valid UUID-like value" >&2
  exit 64
fi

deadline=$((SECONDS + 900))
while ((SECONDS < deadline)); do
  parameters="$(jq -cn --arg deployment_uuid "${DEPLOYMENT_UUID}" \
    '{commands:["sudo /usr/local/bin/talkdesk-coolify-deployment-status " + $deployment_uuid]}')"
  command_id="$(aws ssm send-command \
    --region "${AWS_REGION}" \
    --document-name AWS-RunShellScript \
    --instance-ids "${COOLIFY_INSTANCE_ID}" \
    --parameters "${parameters}" \
    --query 'Command.CommandId' \
    --output text)"

  invocation_deadline=$((SECONDS + 90))
  while ((SECONDS < invocation_deadline)); do
    invocation="$(aws ssm get-command-invocation \
      --region "${AWS_REGION}" \
      --command-id "${command_id}" \
      --instance-id "${COOLIFY_INSTANCE_ID}" \
      --output json 2>/dev/null || true)"
    status="$(jq -r '.Status // "pending"' <<<"${invocation}")"
    case "${status}" in
      Success)
        deployment="$(jq -er '.StandardOutputContent | fromjson' <<<"${invocation}")"
        coolify_status="$(jq -r '.status // "unknown"' <<<"${deployment}")"
        printf 'Coolify deployment %s status: %s\n' "${DEPLOYMENT_UUID}" "${coolify_status}"
        case "${coolify_status}" in
          finished|success|successful) exit 0 ;;
          failed|cancelled|canceled) exit 1 ;;
        esac
        break
        ;;
      Cancelled|Cancelling|Failed|TimedOut)
        jq -r '.StandardErrorContent // empty' <<<"${invocation}" >&2
        exit 1
        ;;
    esac
    sleep 3
  done
  sleep 7
done

echo "Timed out waiting for Coolify deployment" >&2
exit 1
