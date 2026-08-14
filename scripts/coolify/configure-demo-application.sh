#!/usr/bin/env bash
set -euo pipefail

: "${COOLIFY_BASE_URL:?COOLIFY_BASE_URL is required}"
: "${COOLIFY_TOKEN:?COOLIFY_TOKEN is required}"
: "${COOLIFY_PROJECT_UUID:?COOLIFY_PROJECT_UUID is required}"
: "${COOLIFY_SERVER_UUID:?COOLIFY_SERVER_UUID is required}"
: "${COOLIFY_ENVIRONMENT_UUID:?COOLIFY_ENVIRONMENT_UUID is required}"

: "${DEMO_IMAGE_REFERENCE:?DEMO_IMAGE_REFERENCE must be an immutable image digest}"
: "${AUTH_AUDIENCE:?AUTH_AUDIENCE is required}"
: "${AUTH_HS256_SECRET:?AUTH_HS256_SECRET is required}"
: "${AUTH_ISSUER:?AUTH_ISSUER is required}"
: "${JAEGER_ZIPKIN_URL:?JAEGER_ZIPKIN_URL is required}"
: "${LOKI_URL:?LOKI_URL is required}"
: "${OBSERVENOW_PASSWORD:?OBSERVENOW_PASSWORD is required}"
: "${OBSERVENOW_USERNAME:?OBSERVENOW_USERNAME is required}"
: "${VICTORIA_METRICS_URL:?VICTORIA_METRICS_URL is required}"

application_name="${COOLIFY_APPLICATION_NAME:-talkdesk-coolify-demo}"
api_base="${COOLIFY_BASE_URL%/}/api/v1"

curl_api() {
  curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer ${COOLIFY_TOKEN}" \
    --header 'Content-Type: application/json' \
    "$@"
}

application_uuid="$(curl_api "${api_base}/applications" | jq -r --arg name "${application_name}" \
  '[.[] | select(.name == $name)][0].uuid // empty')"

if [[ -z "${application_uuid}" ]]; then
  payload="$(jq -n \
    --arg project_uuid "${COOLIFY_PROJECT_UUID}" \
    --arg server_uuid "${COOLIFY_SERVER_UUID}" \
    --arg environment_uuid "${COOLIFY_ENVIRONMENT_UUID}" \
    --arg name "${application_name}" \
    --rawfile compose app/docker-compose.yml \
    '{project_uuid:$project_uuid,server_uuid:$server_uuid,environment_uuid:$environment_uuid,name:$name,docker_compose_raw:$compose,instant_deploy:false,autogenerate_domain:false}')"
  application_uuid="$(curl_api --request POST --data "${payload}" "${api_base}/applications/dockercompose" | jq -er '.uuid')"
fi

set_env() {
  local key="$1"
  local value="$2"
  local payload
  payload="$(jq -n --arg key "${key}" --arg value "${value}" '{key:$key,value:$value,is_literal:true}')"
  curl_api --request PATCH --data "${payload}" "${api_base}/applications/${application_uuid}/envs" >/dev/null
}

set_env DEMO_IMAGE_REFERENCE "${DEMO_IMAGE_REFERENCE}"
set_env AUTH_AUDIENCE "${AUTH_AUDIENCE}"
set_env AUTH_HS256_SECRET "${AUTH_HS256_SECRET}"
set_env AUTH_ISSUER "${AUTH_ISSUER}"
set_env DEPLOYMENT_ENVIRONMENT "${DEPLOYMENT_ENVIRONMENT:-demo}"
set_env JAEGER_ZIPKIN_URL "${JAEGER_ZIPKIN_URL}"
set_env LOKI_URL "${LOKI_URL}"
set_env OBSERVENOW_PASSWORD "${OBSERVENOW_PASSWORD}"
set_env OBSERVENOW_USERNAME "${OBSERVENOW_USERNAME}"
set_env VICTORIA_METRICS_URL "${VICTORIA_METRICS_URL}"

printf 'COOLIFY_APPLICATION_UUID=%s\n' "${application_uuid}"
