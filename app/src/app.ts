import crypto from "node:crypto";
import express, { type ErrorRequestHandler } from "express";
import type { TokenVerifier } from "./auth.js";
import { requireAuthentication } from "./auth.js";
import { log } from "./logger.js";
import { annotateActiveSpan, recordRequest } from "./telemetry.js";

export function createApp(verifyToken: TokenVerifier) {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "16kb" }));

  app.use((request, response, next) => {
    const startedAt = performance.now();
    const requestId = request.header("x-request-id") ?? crypto.randomUUID();
    const demoRunId = request.header("x-demo-run-id") ?? "unassigned";
    annotateActiveSpan(demoRunId, requestId);
    response.setHeader("x-request-id", requestId);
    response.setHeader("x-content-type-options", "nosniff");
    response.setHeader("referrer-policy", "no-referrer");
    response.setHeader("content-security-policy", "default-src 'none'; frame-ancestors 'none'");
    response.on("finish", () => {
      const route = request.route?.path?.toString() ?? request.path;
      const durationMs = performance.now() - startedAt;
      recordRequest(request.method, route, response.statusCode, durationMs, demoRunId);
      log("info", "request completed", {
        demo_run_id: demoRunId,
        duration_ms: Math.round(durationMs),
        method: request.method,
        path: request.path,
        request_id: requestId,
        status: response.statusCode,
      });
    });
    next();
  });

  app.get("/", (_request, response) => {
    response.type("html").send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Talkdesk Secure Delivery Demo</title></head>
<body><main><h1>Talkdesk Secure Delivery Demo</h1><p>The application is healthy, policy-scanned, and emitting OpenTelemetry.</p></main></body></html>`);
  });
  app.get("/healthz", (_request, response) => response.json({ status: "ok" }));
  app.get("/readyz", (_request, response) => response.json({ status: "ready" }));
  app.get("/api/public", (request, response) => {
    response.json({ demo_run_id: request.header("x-demo-run-id") ?? "unassigned", status: "ok" });
  });
  app.get("/api/profile", requireAuthentication(verifyToken), (_request, response) => {
    response.json({ principal: response.locals.principal });
  });

  app.use((_request, response) => response.status(404).json({ error: "not_found" }));

  const errorHandler: ErrorRequestHandler = (error, request, response, _next) => {
    log("error", "request failed", {
      demo_run_id: request.header("x-demo-run-id"),
      reason: error instanceof Error ? error.name : "unknown_error",
    });
    response.status(500).json({ error: "internal_server_error" });
  };
  app.use(errorHandler);
  return app;
}
