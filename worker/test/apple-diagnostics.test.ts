import { afterEach, describe, expect, it, vi } from "vitest";
import { errors, exportPKCS8, generateKeyPair } from "jose";
import { appleIdentityFailure, exchangeApple, type Env } from "../src/auth";

afterEach(() => vi.restoreAllMocks());
describe("safe Apple authentication diagnostics", () => {
    it.each([
        ["invalid_client", 503, "apple_client_invalid"],
        ["invalid_grant", 401, "apple_code_invalid"],
        ["unrecognized-sensitive-response", 503, "apple_authorization_failed"],
    ])(
        "classifies Apple authorization errors (%s)",
        async (error, status, diagnostic) => {
            const log = vi.spyOn(console, "warn").mockImplementation(() => {});
            const keys = await generateKeyPair("ES256", { extractable: true });
            const env = {
                APPLE_CLIENT_ID: "test",
                APPLE_TEAM_ID: "team",
                APPLE_KEY_ID: "key",
                APPLE_PRIVATE_KEY: (await exportPKCS8(keys.privateKey)).replace(
                    /\n/g,
                    "\\n",
                ),
            } as Env;
            vi.spyOn(globalThis, "fetch").mockResolvedValue(
                Response.json({ error }, { status: 400 }),
            );
            await expect(
                exchangeApple("secret-code", env),
            ).rejects.toMatchObject({
                status,
                code: diagnostic,
            });
            expect(JSON.stringify(log.mock.calls)).not.toMatch(
                /secret-code|unrecognized-sensitive-response|PRIVATE KEY/,
            );
            vi.mocked(globalThis.fetch).mockRejectedValue(
                new Error("sensitive network details"),
            );
            await expect(
                exchangeApple("secret-code", env),
            ).rejects.toMatchObject({
                status: 503,
                code: "apple_service_unavailable",
            });
            expect(JSON.stringify(log.mock.calls)).not.toContain("sensitive");
        },
    );
    it.each([
        [
            new errors.JWTClaimValidationFailed(
                "sensitive",
                { sub: "private-user" },
                "aud",
            ),
            401,
            "apple_audience_mismatch",
        ],
        [
            new errors.JWTClaimValidationFailed("sensitive", {}, "iss"),
            401,
            "apple_claim_invalid",
        ],
        [new errors.JWTExpired("sensitive", {}), 401, "apple_token_expired"],
        [
            new errors.JWSSignatureVerificationFailed("sensitive"),
            401,
            "apple_signature_invalid",
        ],
        [new errors.JWTInvalid("sensitive"), 401, "apple_token_invalid"],
        [new errors.JWKSTimeout("sensitive"), 503, "apple_keys_unavailable"],
        [
            new TypeError("sensitive network details"),
            503,
            "apple_keys_unavailable",
        ],
    ])(
        "classifies failures without exposing exceptions (%s)",
        (error, status, code) => {
            const log = vi.spyOn(console, "warn").mockImplementation(() => {});
            const failure = appleIdentityFailure(error);
            expect(failure.status).toBe(status);
            expect(failure.code).toBe(code);
            const record = JSON.parse(log.mock.calls[0][0]);
            expect(record).toEqual({
                event: "apple_auth_failed",
                code,
                reference: expect.any(String),
                hint: expect.any(String),
            });
            expect(failure.reference).toBe(record.reference);
            expect(failure.message).not.toMatch(
                /APPLE_|P8|Worker|DNS|proxy|audience/,
            );
            expect(
                JSON.stringify(log.mock.calls) + failure.message,
            ).not.toMatch(/sensitive|private-user/);
        },
    );
    it("explains missing credentials and rejects a P8 filename without leaking it", async () => {
        const log = vi.spyOn(console, "warn").mockImplementation(() => {});
        const env = {
            APPLE_CLIENT_ID: "test",
            APPLE_TEAM_ID: "team",
            APPLE_KEY_ID: "key",
            APPLE_PRIVATE_KEY: "",
        } as Env;
        await expect(exchangeApple("secret-code", env)).rejects.toMatchObject({
            code: "apple_credentials_missing",
        });
        env.APPLE_PRIVATE_KEY = "AuthKey_PRIVATE.p8";
        await expect(exchangeApple("secret-code", env)).rejects.toMatchObject({
            code: "apple_private_key_invalid",
        });
        expect(JSON.stringify(log.mock.calls)).not.toMatch(
            /AuthKey_PRIVATE|secret-code/,
        );
    });
});
