import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";
export default defineConfig(async () => ({
    plugins: [
        cloudflareTest({
            wrangler: { configPath: "./wrangler.jsonc" },
            miniflare: {
                bindings: {
                    TEST_MIGRATIONS: await readD1Migrations("./migrations"),
                    SESSION_SECRET:
                        "test-only-signing-secret-with-at-least-32-bytes",
                    TOKEN_ENCRYPTION_KEY:
                        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                    APPLE_TEAM_ID: "TESTTEAM",
                    APPLE_KEY_ID: "TESTKEY",
                },
            },
        }),
    ],
}));
