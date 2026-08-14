import type { RequestHandler } from "express";
import { jwtVerify } from "jose";
import type { AppConfig } from "./config.js";
import { log } from "./logger.js";

export type TokenVerifier = (token: string) => Promise<Record<string, unknown>>;

export function createTokenVerifier(config: AppConfig): TokenVerifier {
  const key = new TextEncoder().encode(config.AUTH_HS256_SECRET);
  return async (token: string) => {
    const result = await jwtVerify(token, key, {
      algorithms: ["HS256"],
      issuer: config.AUTH_ISSUER,
      audience: config.AUTH_AUDIENCE,
    });
    return result.payload;
  };
}

export function requireAuthentication(verifyToken: TokenVerifier): RequestHandler {
  return async (request, response, next) => {
    const authorization = request.header("authorization") ?? "";
    const [scheme, token] = authorization.split(" ", 2);
    if (scheme !== "Bearer" || !token) {
      response.status(401).json({ error: "unauthorized", reason: "missing_bearer_token" });
      return;
    }

    try {
      response.locals.principal = await verifyToken(token);
      next();
    } catch (error) {
      log("warn", "authentication rejected", {
        demo_run_id: request.header("x-demo-run-id"),
        reason: error instanceof Error ? error.name : "unknown_error",
      });
      response.status(401).json({ error: "unauthorized", reason: "invalid_token" });
    }
  };
}
