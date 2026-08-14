import { logs, SeverityNumber } from "@opentelemetry/api-logs";
import { currentTraceId } from "./telemetry.js";

type Fields = Record<string, boolean | number | string | undefined>;

const otelLogger = logs.getLogger("talkdesk-demo-app");

export function log(level: "error" | "info" | "warn", message: string, fields: Fields = {}): void {
  const body = {
    level,
    message,
    trace_id: currentTraceId(),
    ...fields,
  };
  process.stdout.write(`${JSON.stringify(body)}\n`);
  otelLogger.emit({
    body: message,
    severityNumber:
      level === "error" ? SeverityNumber.ERROR : level === "warn" ? SeverityNumber.WARN : SeverityNumber.INFO,
    severityText: level.toUpperCase(),
    attributes: Object.fromEntries(Object.entries(body).filter(([, value]) => value !== undefined)),
  });
}
