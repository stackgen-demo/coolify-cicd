import { SignJWT } from "jose";
import { describe, expect, it } from "vitest";
import { createTokenVerifier } from "./auth.js";
import type { AppConfig } from "./config.js";

const config: AppConfig = {
  PORT: 3000,
  AUTH_ISSUER: "https://auth.demo.invalid/",
  AUTH_AUDIENCE: "talkdesk-coolify-demo",
  AUTH_HS256_SECRET: "01234567890123456789012345678901",
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://collector.invalid:4318",
  OTEL_SERVICE_NAME: "talkdesk-coolify-demo",
};

const sign = async ({
  audience = config.AUTH_AUDIENCE,
  expiresAt = Math.floor(Date.now() / 1000) + 300,
  secret = config.AUTH_HS256_SECRET,
} = {}) =>
  new SignJWT({ sub: "demo-user" })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(config.AUTH_ISSUER)
    .setAudience(audience)
    .setExpirationTime(expiresAt)
    .sign(new TextEncoder().encode(secret));

describe("authentication compliance", () => {
  const verify = createTokenVerifier(config);

  it("accepts the configured issuer, audience, signature, and lifetime", async () => {
    await expect(verify(await sign())).resolves.toMatchObject({ sub: "demo-user" });
  });

  it("rejects the wrong audience", async () => {
    await expect(verify(await sign({ audience: "wrong-audience" }))).rejects.toThrow();
  });

  it("rejects an expired token", async () => {
    await expect(verify(await sign({ expiresAt: Math.floor(Date.now() / 1000) - 30 }))).rejects.toThrow();
  });

  it("rejects the wrong signature", async () => {
    await expect(verify(await sign({ secret: "abcdefghijklmnopqrstuvwxyz123456" }))).rejects.toThrow();
  });
});
