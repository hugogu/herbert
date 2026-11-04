import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { unstable_dev } from "wrangler";

test(
    "real Worker entrypoint starts with migrated local D1 and enforces authentication",
    { timeout: 60000 },
    async () => {
        const state = await mkdtemp(join(tmpdir(), "herbert-worker-runtime-"));
        let worker;
        try {
            execFileSync(
                process.execPath,
                [
                    "node_modules/wrangler/bin/wrangler.js",
                    "d1",
                    "migrations",
                    "apply",
                    "DB",
                    "--local",
                    "--env=",
                    "--persist-to",
                    state,
                ],
                {
                    env: { ...process.env, CLOUDFLARE_SEND_METRICS: "false" },
                    stdio: ["ignore", "pipe", "pipe"],
                    timeout: 30000,
                },
            );
            worker = await unstable_dev("src/index.ts", {
                config: "wrangler.jsonc",
                env: "",
                local: true,
                persist: true,
                persistTo: state,
                port: 0,
                inspectorPort: 0,
                logLevel: "none",
                experimental: {
                    disableExperimentalWarning: true,
                    disableDevRegistry: true,
                },
            });
            const response = await worker.fetch("/v1/problems");
            assert.equal(response.status, 200);
            assert.equal(response.headers.get("Cache-Control"), "no-store");
            const catalog = await response.json();
            assert.equal(catalog.rules_version, "herbert-h-v1");
            const originals = JSON.parse(
                await readFile(
                    new URL(
                        "../../Sources/HerbertCore/Resources/original-problems.json",
                        import.meta.url,
                    ),
                    "utf8",
                ),
            );
            assert.deepEqual(
                catalog.problems.map((p) => p.problem_id),
                originals.map((p) => p.id),
            );

            const ranking = await worker.fetch("/v1/leaderboard");
            assert.equal(ranking.status, 200);
            const problemRanking = await worker.fetch(
                `/v1/problems/${catalog.problems[0].problem_id}/leaderboard`,
            );
            assert.equal(problemRanking.status, 200);
            assert.equal(
                problemRanking.headers.get("Cache-Control"),
                "no-store",
            );
            assert.deepEqual((await problemRanking.json()).entries, []);
            const challenge = await worker.fetch("/v1/auth/challenge", {
                method: "POST",
            });
            assert.equal(challenge.status, 200);
            assert.equal(typeof (await challenge.json()).nonce, "string");

            const privateResponse = await worker.fetch("/v1/me");
            assert.equal(privateResponse.status, 401);
            const submission = await worker.fetch("/v1/submissions", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: "{}",
            });
            assert.equal(submission.status, 401);
        } finally {
            await worker?.stop();
            await rm(state, { recursive: true, force: true });
        }
    },
);
