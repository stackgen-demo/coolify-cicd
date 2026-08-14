import { createApp } from "./app.js";
import { createTokenVerifier } from "./auth.js";
import { loadConfig } from "./config.js";
import { startTelemetry } from "./instrumentation.js";
import { log } from "./logger.js";

const config = loadConfig();
const stopTelemetry = await startTelemetry(config);
const app = createApp(createTokenVerifier(config));
const server = app.listen(config.PORT, "0.0.0.0", () => {
  log("info", "server started", { port: config.PORT, service: config.OTEL_SERVICE_NAME });
});

async function shutdown(signal: string): Promise<void> {
  log("info", "server stopping", { signal });
  server.close(async () => {
    await stopTelemetry();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));
