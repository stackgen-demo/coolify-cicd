#!/usr/bin/env bash
set -euo pipefail

: "${DEMO_RUN_ID:?DEMO_RUN_ID is required}"
: "${GRAFANA_READER_TOKEN:?GRAFANA_READER_TOKEN is required}"
: "${GRAFANA_URL:?GRAFANA_URL is required}"
: "${JAEGER_DATASOURCE_UID:?JAEGER_DATASOURCE_UID is required}"
: "${LOKI_URL:?LOKI_URL is required}"
: "${OBSERVENOW_PASSWORD:?OBSERVENOW_PASSWORD is required}"
: "${OBSERVENOW_USERNAME:?OBSERVENOW_USERNAME is required}"
: "${OPSVERSE_METRIC_QUERY:?OPSVERSE_METRIC_QUERY is required}"
: "${VICTORIA_METRICS_QUERY_URL:?VICTORIA_METRICS_QUERY_URL is required}"

mkdir -p evidence/observability

metric_query="talkdesk_demo_http_requests_total{demo_run_id=\"${DEMO_RUN_ID}\"}"
trace_tags="$(jq -cn --arg id "${DEMO_RUN_ID}" '{"demo.run_id":$id}')"

metrics_found=false
logs_found=false
traces_found=false
opsverse_found=false

for _ in $(seq 1 12); do
  metrics="$(curl --fail-with-body --silent --show-error --get \
    --user "${OBSERVENOW_USERNAME}:${OBSERVENOW_PASSWORD}" \
    --data-urlencode "query=${metric_query}" "${VICTORIA_METRICS_QUERY_URL}")"
  logs="$(curl --fail-with-body --silent --show-error --get \
    --user "${OBSERVENOW_USERNAME}:${OBSERVENOW_PASSWORD}" \
    --data-urlencode "query={service_name=\"talkdesk-coolify-demo\"} |= \"${DEMO_RUN_ID}\"" \
    --data-urlencode "limit=20" "${LOKI_URL%/}/loki/api/v1/query_range")"
  traces="$(curl --fail-with-body --silent --show-error --get \
    --header "Authorization: Bearer ${GRAFANA_READER_TOKEN}" \
    --data-urlencode "service=talkdesk-coolify-demo" \
    --data-urlencode "tags=${trace_tags}" \
    "${GRAFANA_URL%/}/api/datasources/proxy/uid/${JAEGER_DATASOURCE_UID}/api/traces")"
  opsverse="$(curl --fail-with-body --silent --show-error --get \
    --user "${OBSERVENOW_USERNAME}:${OBSERVENOW_PASSWORD}" \
    --data-urlencode "query=${OPSVERSE_METRIC_QUERY}" "${VICTORIA_METRICS_QUERY_URL}")"

  [[ "$(jq '.data.result | length' <<<"${metrics}")" -gt 0 ]] && metrics_found=true
  [[ "$(jq '.data.result | length' <<<"${logs}")" -gt 0 ]] && logs_found=true
  [[ "$(jq '.data | length' <<<"${traces}")" -gt 0 ]] && traces_found=true
  [[ "$(jq '.data.result | length' <<<"${opsverse}")" -gt 0 ]] && opsverse_found=true
  if [[ "${metrics_found}" == true && "${logs_found}" == true && "${traces_found}" == true && "${opsverse_found}" == true ]]; then break; fi
  sleep 10
done

jq -n \
  --argjson metrics "${metrics_found}" \
  --argjson logs "${logs_found}" \
  --argjson traces "${traces_found}" \
  --argjson opsverse "${opsverse_found}" \
  '{metrics:$metrics,logs:$logs,traces:$traces,opsverse_agent_healthy:$opsverse,correlation_complete:($metrics and $logs and $traces)}' \
  > evidence/observability/status.json

[[ "${metrics_found}" == true && "${logs_found}" == true && "${traces_found}" == true && "${opsverse_found}" == true ]]
