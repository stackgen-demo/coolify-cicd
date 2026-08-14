import { logs } from "@opentelemetry/api-logs";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPLogExporter } from "@opentelemetry/exporter-logs-otlp-http";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { BatchLogRecordProcessor, LoggerProvider } from "@opentelemetry/sdk-logs";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";
import { NodeSDK } from "@opentelemetry/sdk-node";
import type { AppConfig } from "./config.js";

export async function startTelemetry(config: AppConfig): Promise<() => Promise<void>> {
  const endpoint = config.OTEL_EXPORTER_OTLP_ENDPOINT.replace(/\/$/, "");
  const metricReader = new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: `${endpoint}/v1/metrics` }),
    exportIntervalMillis: 10_000,
  });
  const sdk = new NodeSDK({
    instrumentations: [getNodeAutoInstrumentations()],
    metricReaders: [metricReader],
    serviceName: config.OTEL_SERVICE_NAME,
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
  });
  const loggerProvider = new LoggerProvider({
    resource: resourceFromAttributes({
      "service.name": config.OTEL_SERVICE_NAME,
    }),
    processors: [
      new BatchLogRecordProcessor({
        exporter: new OTLPLogExporter({ url: `${endpoint}/v1/logs` }),
      }),
    ],
  });
  logs.setGlobalLoggerProvider(loggerProvider);
  sdk.start();

  return async () => {
    await Promise.all([sdk.shutdown(), loggerProvider.shutdown()]);
  };
}
