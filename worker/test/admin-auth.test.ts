import { afterEach, describe, expect, it, vi } from "vitest";
import { exportJWK, generateKeyPair, SignJWT } from "jose";
import { authenticateAdmin, type Env } from "../src/auth";

afterEach(() => vi.restoreAllMocks());
describe("bounded administrator key caching", () => {
    it("reuses keys for one validated issuer and replaces them when the issuer changes", async () => {
        const keys = await generateKeyPair("RS256", { extractable: true });
        const jwk = { ...(await exportJWK(keys.publicKey)), kid: "cache-test" };
        const fetch = vi
            .spyOn(globalThis, "fetch")
            .mockImplementation(async () => Response.json({ keys: [jwk] }));
        const env = {
            ADMIN_ISSUER: "https://cache-test.cloudflareaccess.com",
            ADMIN_AUDIENCE: "admin",
            ADMIN_EMAILS: "operator@example.com",
        } as Env;
        async function request() {
            const token = await new SignJWT({ email: "operator@example.com" })
                .setProtectedHeader({ alg: "RS256", kid: "cache-test" })
                .setIssuer(env.ADMIN_ISSUER)
                .setAudience(env.ADMIN_AUDIENCE)
                .setIssuedAt()
                .setExpirationTime("5m")
                .sign(keys.privateKey);
            return new Request("https://api.example.test/admin/v1/users", {
                headers: { "Cf-Access-Jwt-Assertion": token },
            });
        }
        for (let i = 0; i < 2; i++)
            expect(await authenticateAdmin(await request(), env)).toBe(
                "operator@example.com",
            );
        expect(fetch).toHaveBeenCalledTimes(1);
        env.ADMIN_ISSUER = "https://second-test.cloudflareaccess.com";
        expect(await authenticateAdmin(await request(), env)).toBe(
            "operator@example.com",
        );
        expect(fetch).toHaveBeenCalledTimes(2);
        expect(String(fetch.mock.calls[1][0])).toBe(
            "https://second-test.cloudflareaccess.com/cdn-cgi/access/certs",
        );
        env.ADMIN_ISSUER = "https://attacker.example.com";
        await expect(
            authenticateAdmin(await request(), env),
        ).rejects.toMatchObject({ status: 403 });
        expect(fetch).toHaveBeenCalledTimes(2);
    });
});
