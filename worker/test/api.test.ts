import { env } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import type { D1Migration } from "@cloudflare/vitest-plugin";
import {
    beforeAll,
    beforeEach,
    afterEach,
    describe,
    expect,
    it,
    vi,
} from "vitest";
import { exportJWK, exportPKCS8, generateKeyPair, SignJWT } from "jose";
import worker from "../src/index";
import { drainRevocations } from "../src/revocations";
import { puzzleIdentity } from "../src/puzzles";
import { accessToken, Env, hash, now, seal, unseal } from "../src/auth";
import puzzles from "../../Sources/HerbertCore/Resources/original-problems.json";
const bindings = env as unknown as Env & { TEST_MIGRATIONS: D1Migration[] };
const url = "https://api.example.test";
async function request(
    path: string,
    method = "GET",
    body?: unknown,
    token?: string,
    headers: Record<string, string> = {},
) {
    return worker.fetch(
        new Request(url + path, {
            method,
            body: body === undefined ? undefined : JSON.stringify(body),
            headers: {
                "Content-Type": "application/json",
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
                ...headers,
            },
        }),
        bindings,
    );
}
async function user(id = "alice") {
    await bindings.DB.prepare(
        "INSERT INTO users(user_id,apple_subject,display_name,created_at) VALUES(?,?,?,?)",
    )
        .bind(id, `apple-${id}`, id, now())
        .run();
    await bindings.DB.prepare(
        "INSERT INTO sessions(session_id,user_id,refresh_hash,expires_at) VALUES(?,?,?,?)",
    )
        .bind(`session-${id}`, id, await hash(`refresh-${id}`), now() + 86400)
        .run();
    return accessToken(id, `session-${id}`, bindings);
}
async function submit(token: string, extra: Record<string, unknown> = {}) {
    return request(
        "/v1/submissions",
        "POST",
        {
            request_id: "request-1",
            problem_id: puzzles[0].id,
            puzzle_version: await hash(puzzleIdentity(puzzles[0])),
            source: "s",
            ...extra,
        },
        token,
    );
}
let appleKeys: Awaited<ReturnType<typeof generateKeyPair>>;
let appleJWK: Awaited<ReturnType<typeof exportJWK>>;
beforeAll(async () => {
    await applyD1Migrations(bindings.DB, bindings.TEST_MIGRATIONS);
    appleKeys = await generateKeyPair("RS256", { extractable: true });
    appleJWK = { ...(await exportJWK(appleKeys.publicKey)), kid: "apple-test" };
});
async function appleJWT(
    claims: Record<string, unknown> = {},
    audience = bindings.APPLE_CLIENT_ID,
) {
    return new SignJWT(claims)
        .setProtectedHeader({ alg: "RS256", kid: "apple-test" })
        .setSubject("apple-alice")
        .setIssuer("https://appleid.apple.com")
        .setAudience(audience)
        .setIssuedAt()
        .setExpirationTime("5m")
        .sign(appleKeys.privateKey);
}
let mockFetch: ReturnType<typeof vi.spyOn>;
beforeEach(async () => {
    bindings.TOKEN_ENCRYPTION_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    await bindings.DB.batch(
        [
            "apple_revocations",
            "admin_audit",
            "submissions",
            "sessions",
            "users",
            "rate_limits",
            "challenges",
            "apple_events",
        ].map((table) => bindings.DB.prepare(`DELETE FROM ${table}`)),
    );
    mockFetch = vi
        .spyOn(globalThis, "fetch")
        .mockRejectedValue(new Error("Unexpected outbound request"));
});
afterEach(() => {
    vi.restoreAllMocks();
});
describe("Worker + real D1 bindings", () => {
    it.each(["network", "invalid_client", "rotated_key"])(
        "deletes locally despite Apple %s failures and bounds background retries",
        async (failure) => {
            const token = await user();
            await submit(token);
            const keys = await generateKeyPair("ES256", { extractable: true });
            bindings.APPLE_PRIVATE_KEY = await exportPKCS8(keys.privateKey);
            const cipher = await seal("private-refresh", bindings);
            await bindings.DB.prepare(
                "UPDATE users SET apple_refresh_cipher=? WHERE user_id='alice'",
            )
                .bind(cipher)
                .run();
            if (failure === "rotated_key")
                bindings.TOKEN_ENCRYPTION_KEY =
                    "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=";
            if (failure === "invalid_client")
                mockFetch.mockResolvedValue(
                    Response.json({ error: "invalid_client" }, { status: 400 }),
                );
            expect(
                (await request("/v1/me", "DELETE", undefined, token)).status,
            ).toBe(200);
            expect(mockFetch).not.toHaveBeenCalled();
            expect(
                (await request("/v1/me", "GET", undefined, token)).status,
            ).toBe(401);
            expect(
                await bindings.DB.prepare(
                    "SELECT source FROM submissions",
                ).first(),
            ).toEqual({ source: "" });
            await drainRevocations(bindings);
            const job = await bindings.DB.prepare(
                "SELECT status,cipher,attempts,next_attempt_at FROM apple_revocations",
            ).first<{
                status: string;
                cipher: string | null;
                attempts: number;
                next_attempt_at: number;
            }>();
            expect(job!.attempts).toBe(1);
            expect(job!.status).toBe(
                failure === "rotated_key" ? "unrevocable" : "pending",
            );
            if (failure === "rotated_key") expect(job!.cipher).toBeNull();
            else {
                expect(job!.next_attempt_at).toBeGreaterThan(now());
                // Not due yet: avoid retrying on every scheduler tick.
                await drainRevocations(bindings);
                expect(
                    await bindings.DB.prepare(
                        "SELECT attempts FROM apple_revocations",
                    ).first(),
                ).toEqual({ attempts: 1 });
                await bindings.DB.prepare(
                    "UPDATE apple_revocations SET next_attempt_at=0",
                ).run();
                mockFetch.mockResolvedValue(
                    new Response(null, { status: 200 }),
                );
                await drainRevocations(bindings);
                expect(
                    await bindings.DB.prepare(
                        "SELECT status,cipher,attempts FROM apple_revocations",
                    ).first(),
                ).toEqual({ status: "revoked", cipher: null, attempts: 2 });
            }
        },
    );
    it("gives up after eight Apple failures without retaining credentials", async () => {
        const token = await user();
        const cipher = await seal("private-refresh", bindings);
        await bindings.DB.prepare(
            "UPDATE users SET apple_refresh_cipher=? WHERE user_id='alice'",
        )
            .bind(cipher)
            .run();
        expect(
            (await request("/v1/me", "DELETE", undefined, token)).status,
        ).toBe(200);
        await bindings.DB.prepare(
            "UPDATE apple_revocations SET attempts=7",
        ).run();
        await drainRevocations(bindings);
        expect(
            await bindings.DB.prepare(
                "SELECT status,cipher,attempts FROM apple_revocations",
            ).first(),
        ).toEqual({ status: "exhausted", cipher: null, attempts: 8 });
    });
    it("rolls back the revocation outbox when local erasure cannot commit", async () => {
        const token = await user();
        const cipher = await seal("private-refresh", bindings);
        await bindings.DB.prepare(
            "UPDATE users SET apple_refresh_cipher=? WHERE user_id='alice'",
        )
            .bind(cipher)
            .run();
        await bindings.DB.exec(
            "CREATE TRIGGER fail_erasure BEFORE UPDATE OF status ON users WHEN NEW.status='deleted' BEGIN SELECT RAISE(ABORT,'test erasure failure'); END;",
        );
        try {
            expect(
                (await request("/v1/me", "DELETE", undefined, token)).status,
            ).toBe(500);
            expect(
                await bindings.DB.prepare(
                    "SELECT COUNT(*) count FROM apple_revocations",
                ).first(),
            ).toEqual({ count: 0 });
            expect(
                (await request("/v1/me", "GET", undefined, token)).status,
            ).toBe(200);
        } finally {
            await bindings.DB.exec("DROP TRIGGER fail_erasure;");
        }
    });
    it("ranks each player's best verified attempt for one problem without exposing programs", async () => {
        const alice = await user(),
            bob = await user("bob");
        await submit(alice, { source: "r" });
        await submit(alice, { request_id: "better", source: "s" });
        await submit(alice, { request_id: "duplicate", source: "s" });
        await submit(bob, { source: "r" });
        const response = await request(
            `/v1/problems/${puzzles[0].id}/leaderboard`,
        );
        expect(response.status).toBe(200);
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect(await response.json()).toEqual({
            problem_id: puzzles[0].id,
            puzzle_version: await hash(puzzleIdentity(puzzles[0])),
            entries: [
                {
                    rank: 1,
                    user_id: "alice",
                    display_name: "alice",
                    points: 80,
                    bytes: 1,
                    accepted: 1,
                    lit_targets: 1,
                    target_count: 1,
                    steps: 1,
                },
                {
                    rank: 2,
                    user_id: "bob",
                    display_name: "bob",
                    points: 0,
                    bytes: 1,
                    accepted: 0,
                    lit_targets: 0,
                    target_count: 1,
                    steps: 1,
                },
            ],
        });
        const limited = await (
            await request(`/v1/problems/${puzzles[0].id}/leaderboard?limit=1`)
        ).json<{ entries: unknown[] }>();
        expect(limited.entries).toHaveLength(1);
        expect((await request("/v1/problems/999999/leaderboard")).status).toBe(
            404,
        );
        const empty = await (
            await request(`/v1/problems/${puzzles[1].id}/leaderboard`)
        ).json<{ entries: unknown[] }>();
        expect(empty.entries).toEqual([]);
    });
    it("excludes hidden, stale, moderated and obsolete-rule results from problem rankings", async () => {
        for (const name of [
            "visible",
            "hidden",
            "stale",
            "blocked",
            "deleted",
            "oldrules",
        ]) {
            await submit(await user(name));
        }
        await bindings.DB.batch([
            bindings.DB.prepare(
                "UPDATE submissions SET hidden_at=? WHERE user_id='hidden'",
            ).bind(now()),
            bindings.DB.prepare(
                "UPDATE submissions SET puzzle_version='retired' WHERE user_id='stale'",
            ),
            bindings.DB.prepare(
                "UPDATE users SET status='blocked' WHERE user_id='blocked'",
            ),
            bindings.DB.prepare(
                "UPDATE users SET status='deleted' WHERE user_id='deleted'",
            ),
            bindings.DB.prepare(
                "UPDATE submissions SET rules_version='retired' WHERE user_id='oldrules'",
            ),
        ]);
        const board = await (
            await request(`/v1/problems/${puzzles[0].id}/leaderboard`)
        ).json<{ entries: { user_id: string }[] }>();
        expect(board.entries.map((entry) => entry.user_id)).toEqual([
            "visible",
        ]);
    });
    it("returns minimum accepted sizes independently of score, instruction count and ranking limit", async () => {
        const alice = await user();
        await submit(alice, { source: "r", request_id: "partial" });
        const empty = await (
            await request("/v1/problems/bests")
        ).json<{ entries: unknown[] }>();
        expect(empty.entries).toEqual([]);
        await submit(alice, { source: "s", request_id: "long" });
        await submit(alice, { source: "s", request_id: "short" });
        // The shortest accepted answer need not be the highest-scoring attempt.
        await bindings.DB.prepare(
            "UPDATE submissions SET points=100,bytes=5,steps=5 WHERE request_id='long'",
        ).run();
        const ranking = await (
            await request(`/v1/problems/${puzzles[0].id}/leaderboard?limit=1`)
        ).json<{ entries: { bytes: number; steps: number }[] }>();
        expect(ranking.entries[0]).toMatchObject({ bytes: 5, steps: 5 });
        const response = await request("/v1/problems/bests");
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect(await response.json()).toEqual({
            rules_version: "herbert-h-v1",
            entries: [
                {
                    problem_id: puzzles[0].id,
                    puzzle_version: await hash(puzzleIdentity(puzzles[0])),
                    bytes: 1,
                },
            ],
        });
    });
    it("excludes rejected, hidden, stale and moderated attempts from best-size references", async () => {
        for (const name of [
            "visible",
            "hidden",
            "stale",
            "blocked",
            "deleted",
            "oldrules",
            "retired",
            "rejected",
        ]) {
            await submit(await user(name));
        }
        await bindings.DB.batch([
            bindings.DB.prepare(
                "UPDATE submissions SET bytes=4 WHERE user_id='visible'",
            ),
            bindings.DB.prepare(
                "UPDATE submissions SET hidden_at=? WHERE user_id='hidden'",
            ).bind(now()),
            bindings.DB.prepare(
                "UPDATE submissions SET puzzle_version='retired' WHERE user_id='stale'",
            ),
            bindings.DB.prepare(
                "UPDATE users SET status='blocked' WHERE user_id='blocked'",
            ),
            bindings.DB.prepare(
                "UPDATE users SET status='deleted' WHERE user_id='deleted'",
            ),
            bindings.DB.prepare(
                "UPDATE submissions SET rules_version='retired' WHERE user_id='oldrules'",
            ),
            bindings.DB.prepare(
                "UPDATE submissions SET problem_id=999999 WHERE user_id='retired'",
            ),
            bindings.DB.prepare(
                "UPDATE submissions SET accepted=0 WHERE user_id='rejected'",
            ),
        ]);
        const bests = await (
            await request("/v1/problems/bests")
        ).json<{ entries: { bytes: number }[] }>();
        expect(bests.entries).toHaveLength(1);
        expect(bests.entries[0].bytes).toBe(4);
    });
    it("ranks the newest puzzle without exceeding D1's 100 bound-parameter limit", async () => {
        const token = await user();
        await submit(token);
        const puzzle = puzzles[puzzles.length - 1];
        await bindings.DB.prepare(
            "UPDATE submissions SET problem_id=?,puzzle_version=?",
        )
            .bind(puzzle.id, await hash(puzzleIdentity(puzzle)))
            .run();
        const prepare = bindings.DB.prepare.bind(bindings.DB);
        const counts: number[] = [];
        vi.spyOn(bindings.DB, "prepare").mockImplementation((sql) => {
            const statement = prepare(sql);
            const bind = statement.bind.bind(statement);
            statement.bind = (...values: unknown[]) => {
                counts.push(values.length);
                if (values.length > 100)
                    throw new Error("D1 bound parameter limit exceeded");
                return bind(...values);
            };
            return statement;
        });
        const bests = await request("/v1/problems/bests");
        expect(bests.status).toBe(200);
        expect(await bests.json()).toMatchObject({
            entries: [{ problem_id: puzzle.id, bytes: 1 }],
        });
        const ranking = await request("/v1/leaderboard");
        expect(ranking.status).toBe(200);
        expect(await ranking.json()).toMatchObject({
            puzzle_count: puzzles.length,
            entries: [{ points: 80, solved: 1 }],
        });
        expect(Math.max(...counts)).toBeLessThanOrEqual(100);
    });
    it("breaks problem ranking ties by answer length and stable user ID", async () => {
        for (const name of ["c", "b", "a"]) await submit(await user(name));
        // Equal-score length ties can occur at zero and after score rounding.
        await bindings.DB.prepare(
            "UPDATE submissions SET bytes=2 WHERE user_id='a'",
        ).run();
        const board = await (
            await request(`/v1/problems/${puzzles[0].id}/leaderboard`)
        ).json<{ entries: { user_id: string }[] }>();
        expect(board.entries.map((entry) => entry.user_id)).toEqual([
            "b",
            "c",
            "a",
        ]);
    });
    it("updates only the authenticated user's public nickname, preserving scores and sessions", async () => {
        const alice = await user();
        const bob = await user("bob");
        await submit(alice);
        const result = await request(
            "/v1/me",
            "PATCH",
            { display_name: "  学习者 Alice  ", user_id: "bob" },
            alice,
        );
        expect(result.status).toBe(200);
        expect(result.headers.get("Cache-Control")).toBe("no-store");
        expect(await result.json()).toEqual({
            user_id: "alice",
            display_name: "学习者 Alice",
        });
        expect(
            await (await request("/v1/me", "GET", undefined, bob)).json(),
        ).toEqual({ user_id: "bob", display_name: "bob" });
        const ranking = await (
            await request("/v1/leaderboard")
        ).json<{ entries: { display_name: string }[] }>();
        expect(ranking.entries[0].display_name).toBe("学习者 Alice");
        expect(
            (await request("/v1/me", "PATCH", { display_name: "forged" }))
                .status,
        ).toBe(401);
        for (const display_name of [
            " ",
            "a".repeat(33),
            "bad\nname",
            "bad\u202Ename",
        ])
            expect(
                (await request("/v1/me", "PATCH", { display_name }, alice))
                    .status,
            ).toBe(400);
        const canonical = await request(
            "/v1/me",
            "PATCH",
            { display_name: "Cafe\u0301" },
            alice,
        );
        expect(await canonical.json()).toEqual({
            user_id: "alice",
            display_name: "Café",
        });
    });
    it("public reads and private writes have no cache", async () => {
        const response = await request("/v1/leaderboard");
        expect(response.status).toBe(200);
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect((await submit("forged")).status).toBe(401);
        expect((await request("/v1/me")).status).toBe(401);
    });
    it("judges on server and ignores forged identity and points", async () => {
        const token = await user();
        const response = await submit(token, {
            user_id: "bob",
            points: 99999,
            bytes: 0,
        });
        expect(response.status).toBe(200);
        const data = await response.json<{
            accepted: boolean;
            points: number;
        }>();
        expect(data.accepted).toBe(true);
        expect(data.points).toBe(80);
        const rows = await bindings.DB.prepare(
            "SELECT user_id,points FROM submissions",
        ).all();
        expect(rows.results).toEqual([{ user_id: "alice", points: 80 }]);
        const board = await (
            await request("/v1/leaderboard")
        ).json<{ entries: { percentage: number }[] }>();
        expect(board.entries[0].percentage).toBe(
            Math.round((80 / puzzles.length) * 100) / 100,
        );
    });
    it("keeps one best score per puzzle and rejects stale boards", async () => {
        const token = await user();
        await submit(token);
        await submit(token, { request_id: "request-2" });
        const board = await (
            await request("/v1/leaderboard")
        ).json<{ entries: { points: number; solved: number }[] }>();
        expect(board.entries[0].points).toBe(80);
        expect(board.entries[0].solved).toBe(1);
        expect((await submit(token, { puzzle_version: "old" })).status).toBe(
            409,
        );
    });
    it("idempotently accepts replay and rejects changed replay content", async () => {
        const token = await user();
        const first = await (await submit(token)).json();
        const second = await (
            await submit(token)
        ).json<{ submission_id: string }>();
        expect(second.submission_id).toBe(
            (first as { submission_id: string }).submission_id,
        );
        expect((await submit(token, { source: "ss" })).status).toBe(409);
    });
    it("rotates refresh tokens once and revokes sessions on logout", async () => {
        const token = await user();
        const refreshed = await request("/v1/auth/refresh", "POST", {
            refresh_token: "refresh-alice",
        });
        expect(refreshed.status).toBe(200);
        expect(
            (
                await request("/v1/auth/refresh", "POST", {
                    refresh_token: "refresh-alice",
                })
            ).status,
        ).toBe(401);
        expect(
            (await request("/v1/auth/logout", "POST", {}, token)).status,
        ).toBe(200);
        expect((await request("/v1/me", "GET", undefined, token)).status).toBe(
            401,
        );
    });
    it("does not leak another user submissions or deleted/blocked scores", async () => {
        const alice = await user(),
            bob = await user("bob");
        await submit(alice);
        const data = await (
            await request("/v1/me/submissions", "GET", undefined, bob)
        ).json<{ submissions: unknown[] }>();
        expect(data.submissions).toEqual([]);
        await bindings.DB.prepare(
            "UPDATE users SET status='blocked' WHERE user_id='alice'",
        ).run();
        expect((await submit(alice)).status).toBe(403);
        expect(
            (
                await (
                    await request("/v1/leaderboard")
                ).json<{ entries: unknown[] }>()
            ).entries,
        ).toEqual([]);
    });
    it("expires challenges, rejects replay and rejects invalid Apple signatures", async () => {
        const challenge = await (
            await request("/v1/auth/challenge", "POST")
        ).json<{ challenge_id: string; nonce: string }>();
        const body = {
            ...challenge,
            identity_token: "forged",
            authorization_code: "forged",
        };
        expect((await request("/v1/auth/apple", "POST", body)).status).toBe(
            401,
        );
        expect((await request("/v1/auth/apple", "POST", body)).status).toBe(
            401,
        );
    });
    it("verifies real Apple signatures, audience and nonce, and exchanges the one-time code", async () => {
        const signingKeys = await generateKeyPair("ES256", {
            extractable: true,
        });
        bindings.APPLE_PRIVATE_KEY = await exportPKCS8(signingKeys.privateKey);
        mockFetch.mockImplementation(
            async (input: RequestInfo | URL, init?: RequestInit) => {
                if (String(input) === "https://appleid.apple.com/auth/keys")
                    return Response.json({ keys: [appleJWK] });
                if (String(input) === "https://appleid.apple.com/auth/token") {
                    const body = init?.body as URLSearchParams;
                    expect(body.get("code")).toBe("one-time-code");
                    expect(body.get("grant_type")).toBe("authorization_code");
                    return Response.json({
                        id_token: await appleJWT(),
                        refresh_token: "apple-refresh",
                    });
                }
                throw new Error("Unexpected network request");
            },
        );
        const challenge = await (
            await request("/v1/auth/challenge", "POST")
        ).json<{ challenge_id: string; nonce: string }>();
        const identity = await appleJWT({ nonce: challenge.nonce });
        const body = {
            ...challenge,
            identity_token: identity,
            authorization_code: "one-time-code",
        };
        const login = await request("/v1/auth/apple", "POST", body);
        expect(login.status).toBe(200);
        const session = await login.json<{
            access_token: string;
            user: { user_id: string };
        }>();
        expect(
            (await request("/v1/me", "GET", undefined, session.access_token))
                .status,
        ).toBe(200);
        expect((await request("/v1/auth/apple", "POST", body)).status).toBe(
            401,
        );
        for (const [identity, diagnostic] of [
            [await appleJWT({ nonce: "wrong" }), "apple_nonce_mismatch"],
            [await appleJWT({}, "other-app"), "apple_audience_mismatch"],
        ]) {
            const next = await (
                await request("/v1/auth/challenge", "POST")
            ).json();
            const rejected = await request("/v1/auth/apple", "POST", {
                ...(next as object),
                identity_token: identity,
                authorization_code: "one-time-code",
            });
            expect(rejected.status).toBe(401);
            expect(await rejected.text()).toContain(diagnostic);
        }
        const stored = await bindings.DB.prepare(
            "SELECT apple_refresh_cipher FROM users",
        ).first<{ apple_refresh_cipher: string }>();
        expect(await unseal(stored!.apple_refresh_cipher, bindings)).toBe(
            "apple-refresh",
        );
    });
    it("processes signed Apple revocations once and preserves a later authorization on replay", async () => {
        const token = await user();
        mockFetch.mockImplementation(async () =>
            Response.json({ keys: [appleJWK] }),
        );
        const payload = await appleJWT({
            events: {
                type: "consent-revoked",
                sub: "apple-alice",
                event_time: now(),
            },
        });
        expect(
            (
                await request("/v1/auth/apple/notifications", "POST", {
                    payload: "forged",
                })
            ).status,
        ).toBe(401);
        expect(
            (await request("/v1/auth/apple/notifications", "POST", { payload }))
                .status,
        ).toBe(200);
        expect((await request("/v1/me", "GET", undefined, token)).status).toBe(
            401,
        );
        await bindings.DB.prepare(
            "UPDATE sessions SET revoked_at=NULL WHERE user_id='alice'",
        ).run();
        expect(
            (await request("/v1/auth/apple/notifications", "POST", { payload }))
                .status,
        ).toBe(200);
        expect((await request("/v1/me", "GET", undefined, token)).status).toBe(
            200,
        );
    });
    it("removes uploaded programs and standings when Apple reports account deletion", async () => {
        const token = await user();
        await submit(token);
        mockFetch.mockImplementation(async () =>
            Response.json({ keys: [appleJWK] }),
        );
        const payload = await appleJWT({
            events: JSON.stringify({
                type: "account-deleted",
                sub: "apple-alice",
                event_time: now(),
            }),
        });
        expect(
            (await request("/v1/auth/apple/notifications", "POST", { payload }))
                .status,
        ).toBe(200);
        expect(
            await bindings.DB.prepare("SELECT source FROM submissions").first(),
        ).toEqual({ source: "" });
        expect(
            await bindings.DB.prepare(
                "SELECT status,apple_subject FROM users",
            ).first(),
        ).toEqual({ status: "deleted", apple_subject: null });
    });
    it("encrypts Apple refresh credentials and removes account data", async () => {
        const token = await user();
        await submit(token);
        const cipher = await seal("sensitive-apple-refresh", bindings);
        expect(cipher).not.toContain("sensitive");
        expect(await unseal(cipher, bindings)).toBe("sensitive-apple-refresh");
        const keys = await generateKeyPair("ES256", { extractable: true });
        bindings.APPLE_PRIVATE_KEY = await exportPKCS8(keys.privateKey);
        await bindings.DB.prepare(
            "UPDATE users SET apple_refresh_cipher=? WHERE user_id='alice'",
        )
            .bind(cipher)
            .run();
        mockFetch.mockResolvedValueOnce(new Response("", { status: 200 }));
        expect(
            (await request("/v1/me", "DELETE", undefined, token)).status,
        ).toBe(200);
        const account = await bindings.DB.prepare(
            "SELECT apple_subject,apple_refresh_cipher,status FROM users WHERE user_id='alice'",
        ).first();
        expect(account).toEqual({
            apple_subject: null,
            apple_refresh_cipher: null,
            status: "deleted",
        });
        expect((await request("/v1/me", "GET", undefined, token)).status).toBe(
            401,
        );
        expect(
            await bindings.DB.prepare("SELECT source FROM submissions").first(),
        ).toEqual({ source: "" });
    });
    it("rejects player tokens and forged Access headers on admin routes", async () => {
        const token = await user();
        expect(
            (await request("/admin/v1/users", "GET", undefined, token)).status,
        ).toBe(403);
        expect(
            (
                await request("/admin/v1/users", "GET", undefined, token, {
                    "Cf-Access-Authenticated-User-Email": "admin@example.com",
                })
            ).status,
        ).toBe(403);
    });
    it("verifies admin JWT audience and records moderation atomically", async () => {
        const token = await user();
        await submit(token);
        bindings.ADMIN_ISSUER = "https://herbert.cloudflareaccess.com";
        bindings.ADMIN_AUDIENCE = "admin-app";
        bindings.ADMIN_EMAILS = "admin@example.com";
        const keys = await generateKeyPair("RS256", { extractable: true }),
            jwk = await exportJWK(keys.publicKey);
        jwk.kid = "admin";
        mockFetch.mockResolvedValueOnce(Response.json({ keys: [jwk] }));
        const jwt = await new SignJWT({ email: "admin@example.com" })
            .setProtectedHeader({ alg: "RS256", kid: "admin" })
            .setIssuer(bindings.ADMIN_ISSUER)
            .setAudience("admin-app")
            .setIssuedAt()
            .setExpirationTime("5m")
            .sign(keys.privateKey);
        const headers = { "Cf-Access-Jwt-Assertion": jwt };
        expect(
            (
                await request(
                    "/admin/v1/users/alice",
                    "PATCH",
                    { status: "blocked", reason: "test moderation" },
                    undefined,
                    headers,
                )
            ).status,
        ).toBe(200);
        expect(
            await bindings.DB.prepare("SELECT action FROM admin_audit").first(),
        ).toEqual({ action: "user.blocked" });
        expect((await request("/v1/me", "GET", undefined, token)).status).toBe(
            401,
        );
        bindings.ADMIN_ISSUER = "";
        bindings.ADMIN_AUDIENCE = "";
        bindings.ADMIN_EMAILS = "";
    });
    it("limits authenticated submissions before running the judge", async () => {
        const token = await user();
        for (let i = 0; i < 60; i++)
            expect((await submit(token, { request_id: `r-${i}` })).status).toBe(
                200,
            );
        const response = await submit(token, { request_id: "extra" });
        expect(response.status).toBe(429);
        expect(response.headers.get("Retry-After")).toBe("60");
    });
});
