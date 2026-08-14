import fs from "node:fs";
import { SignJWT } from "jose";

const required = ["AUTH_AUDIENCE", "AUTH_HS256_SECRET", "AUTH_ISSUER", "DEMO_RUN_ID", "TARGET_URL"];
for (const name of required) {
  if (!process.env[name]) throw new Error(`${name} is required`);
}

const key = new TextEncoder().encode(process.env.AUTH_HS256_SECRET);
const wrongKey = crypto.getRandomValues(new Uint8Array(32));
const now = Math.floor(Date.now() / 1000);
const makeToken = async ({ audience = process.env.AUTH_AUDIENCE, expiresAt = now + 300, signingKey = key } = {}) =>
  new SignJWT({ sub: "demo-security-probe" })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(process.env.AUTH_ISSUER)
    .setAudience(audience)
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .sign(signingKey);

const cases = {
  missing: undefined,
  malformed: "not-a-jwt",
  expired: await makeToken({ expiresAt: now - 30 }),
  wrong_signature: await makeToken({ signingKey: wrongKey }),
  wrong_audience: await makeToken({ audience: "not-the-demo-audience" }),
  valid: await makeToken(),
};

const results = {};
for (const [name, token] of Object.entries(cases)) {
  const response = await fetch(`${process.env.TARGET_URL.replace(/\/$/, "")}/api/profile`, {
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      "x-demo-run-id": process.env.DEMO_RUN_ID,
      [process.env.WAF_HEADER_NAME ?? "x-demo-client"]: process.env.WAF_HEADER_VALUE ?? "talkdesk-security-demo",
    },
    redirect: "manual",
  });
  results[name] = response.status;
}

fs.mkdirSync("evidence/http", { recursive: true });
fs.writeFileSync("evidence/http/authentication.json", `${JSON.stringify(results, null, 2)}\n`, { mode: 0o600 });
if (results.valid !== 200 || Object.entries(results).some(([name, status]) => name !== "valid" && status !== 401)) process.exit(1);
