#!/usr/bin/env bash
set -euo pipefail

: "${COOLIFY_BASE_URL:?COOLIFY_BASE_URL is required}"
: "${COOLIFY_TOKEN:?COOLIFY_TOKEN is required}"
: "${DEPLOYMENT_UUID:?DEPLOYMENT_UUID is required}"

deadline=$((SECONDS + 900))
while (( SECONDS < deadline )); do
  deployment="$(curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer ${COOLIFY_TOKEN}" \
    "${COOLIFY_BASE_URL%/}/api/v1/deployments/${DEPLOYMENT_UUID}")"
  status="$(jq -r '.status // "unknown"' <<<"${deployment}")"
  printf 'Coolify deployment %s status: %s\n' "${DEPLOYMENT_UUID}" "${status}"
  case "${status}" in
    finished|success|successful) exit 0 ;;
    failed|cancelled|canceled) exit 1 ;;
  esac
  sleep 10
done

echo "Timed out waiting for Coolify deployment" >&2
exit 1
