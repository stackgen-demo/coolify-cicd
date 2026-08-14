import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import { createApp } from "./app.js";

describe("demo application", () => {
  it("serves health checks without authentication", async () => {
    const response = await request(createApp(vi.fn())).get("/healthz");
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
  });

  it("rejects a protected endpoint without a bearer token", async () => {
    const response = await request(createApp(vi.fn())).get("/api/profile");
    expect(response.status).toBe(401);
    expect(response.body.reason).toBe("missing_bearer_token");
  });

  it("rejects a token when verification fails", async () => {
    const verify = vi.fn().mockRejectedValue(new Error("bad token"));
    const response = await request(createApp(verify)).get("/api/profile").set("authorization", "Bearer invalid");
    expect(response.status).toBe(401);
    expect(response.body.reason).toBe("invalid_token");
  });

  it("returns the verified principal", async () => {
    const verify = vi.fn().mockResolvedValue({ sub: "demo-user", role: "viewer" });
    const response = await request(createApp(verify)).get("/api/profile").set("authorization", "Bearer valid");
    expect(response.status).toBe(200);
    expect(response.body.principal.sub).toBe("demo-user");
  });
});
