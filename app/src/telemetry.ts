import { context, metrics, trace } from "@opentelemetry/api";

const meter = metrics.getMeter("talkdesk-demo-http");
const requestCounter = meter.createCounter("talkdesk_demo_http_requests", {
  description: "HTTP requests handled by the demo application",
});
const requestDuration = meter.createHistogram("talkdesk_demo_http_request_duration", {
  description: "HTTP request duration in milliseconds",
  unit: "ms",
});

export function recordRequest(method: string, route: string, status: number, durationMs: number, demoRunId: string): void {
  const attributes = {
    "demo_run_id": demoRunId,
    "http.request.method": method,
    "http.route": route,
    "http.response.status_code": status,
  };
  requestCounter.add(1, attributes);
  requestDuration.record(durationMs, attributes);
}

export function annotateActiveSpan(demoRunId: string, requestId: string): void {
  const span = trace.getSpan(context.active());
  span?.setAttribute("demo.run_id", demoRunId);
  span?.setAttribute("request.id", requestId);
}

export function currentTraceId(): string | undefined {
  return trace.getSpan(context.active())?.spanContext().traceId;
}
