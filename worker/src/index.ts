import { drainRevocations } from "./revocations";
import originals from "../../Sources/HerbertCore/Resources/original-problems.json";
import { evaluate } from "./judge";
import { puzzleIdentity, RULES_VERSION } from "./puzzles";
import {
    accessToken,
    appleNotification,
    authenticate,
    authenticateAdmin,
    Env,
    exchangeApple,
    hash,
    HTTPError,
    now,
    randomToken,
    seal,
    verifyApple,
} from "./auth";
const catalog = Promise.all(
    originals.map(async (p) => ({
        ...p,
        puzzle_version: await hash(puzzleIdentity(p)),
    })),
);
const json = (value: unknown, status = 200) =>
    Response.json(value, {
        status,
        headers: {
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
    });
async function body(request: Request) {
    if (!request.headers.get("Content-Type")?.startsWith("application/json"))
        throw new HTTPError(415, "Expected application/json");
    const reader = request.body?.getReader();
    if (!reader) throw new HTTPError(400, "Missing body");
    const chunks: Uint8Array[] = [];
    let length = 0;
    while (true) {
        const result = await reader.read();
        if (result.done) break;
        length += result.value.length;
        if (length > 32768) {
            await reader.cancel();
            throw new HTTPError(413, "Request exceeds 32 KiB");
        }
        chunks.push(result.value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const c of chunks) {
        bytes.set(c, offset);
        offset += c.length;
    }
    try {
        const data = JSON.parse(new TextDecoder().decode(bytes));
        if (!data || typeof data !== "object" || Array.isArray(data))
            throw new Error();
        return data as Record<string, unknown>;
    } catch {
        throw new HTTPError(400, "Invalid JSON object");
    }
}
function string(data: Record<string, unknown>, key: string, max = 8192) {
    const v = data[key];
    if (typeof v !== "string" || !v || v.length > max)
        throw new HTTPError(400, `Invalid ${key}`);
    return v;
}
async function rateLimit(env: Env, key: string, limit: number, window = 60) {
    const epoch = Math.floor(now() / window),
        bucket = `${key}:${epoch}`;
    const result = await env.DB.prepare(
        `INSERT INTO rate_limits(bucket_key,count,expires_at) VALUES(?,1,?)
    ON CONFLICT(bucket_key) DO UPDATE SET count=count+1 RETURNING count`,
    )
        .bind(bucket, (epoch + 1) * window)
        .first<{ count: number }>();
    if (!result || result.count > limit)
        throw new HTTPError(429, "Too many requests; retry in 60 seconds");
}
async function newSession(env: Env, userID: string) {
    const sessionID = crypto.randomUUID(),
        refresh = randomToken(),
        expiresAt = now() + 30 * 86400;
    const access = await accessToken(userID, sessionID, env);
    await env.DB.prepare(
        "INSERT INTO sessions(session_id,user_id,refresh_hash,expires_at,created_at) VALUES(?,?,?,?,?)",
    )
        .bind(sessionID, userID, await hash(refresh), expiresAt, now())
        .run();
    return {
        access_token: access,
        refresh_token: refresh,
        expires_at: now() + 900,
    };
}
export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        try {
            return await route(request, env);
        } catch (error) {
            const status = error instanceof HTTPError ? error.status : 500;
            const reference =
                error instanceof HTTPError
                    ? error.reference
                    : crypto.randomUUID();
            if (!(error instanceof HTTPError)) {
                // Never log exception messages: database/transport errors can include submitted data.
                console.error(
                    JSON.stringify({
                        event: "request_failed",
                        code: "internal_error",
                        reference,
                    }),
                );
            }
            const response = json(
                {
                    code:
                        error instanceof HTTPError
                            ? error.code
                            : "internal_error",
                    reference,
                    error:
                        error instanceof HTTPError
                            ? error.message
                            : "Service temporarily unavailable",
                },
                status,
            );
            if (status === 429) response.headers.set("Retry-After", "60");
            return response;
        }
    },
    async scheduled(_event: ScheduledController, env: Env) {
        await drainRevocations(env);
        // Tombstones remain; transient authentication/rate-limit state expires.
        await env.DB.batch([
            env.DB.prepare(
                "DELETE FROM apple_revocations WHERE finished_at<?",
            ).bind(now() - 30 * 86400),
            env.DB.prepare("DELETE FROM challenges WHERE expires_at<?").bind(
                now(),
            ),
            env.DB.prepare("DELETE FROM rate_limits WHERE expires_at<?").bind(
                now(),
            ),
            env.DB.prepare("DELETE FROM sessions WHERE expires_at<?").bind(
                now() - 86400,
            ),
        ]);
    },
};
async function route(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url),
        path = url.pathname,
        method = request.method;
    const ipKey = await hash(
        `${env.SESSION_SECRET}:${request.headers.get("CF-Connecting-IP") ?? "unknown"}`,
    );
    await rateLimit(env, `ip:${ipKey}`, 120);
    if (path.startsWith("/admin/")) return admin(request, env, path);
    if (method === "GET" && path === "/v1/problems")
        return json({
            rules_version: RULES_VERSION,
            problems: (await catalog).map((p) => ({
                problem_id: p.id,
                number: `L${String(p.lesson.order).padStart(2, "0")}`,
                puzzle_version: p.puzzle_version,
                byte_limit: p.byteLimit,
            })),
        });
    if (method === "POST" && path === "/v1/auth/apple/notifications") {
        const event = await appleNotification(
            string(await body(request), "payload", 16384),
            env,
        );
        if (
            !["consent-revoked", "account-deleted", "account-delete"].includes(
                event.type,
            )
        )
            return json({ ok: true });
        await env.DB.prepare(
            "INSERT INTO apple_events(event_id,created_at) VALUES(?,?) ON CONFLICT DO NOTHING",
        )
            .bind(event.id, now())
            .run();
        const pending =
            "EXISTS(SELECT 1 FROM apple_events WHERE event_id=? AND handled_at IS NULL)";
        const target =
            "SELECT user_id FROM users WHERE apple_subject=? AND created_at<=?";
        const statements = [
            env.DB.prepare(
                `UPDATE sessions SET revoked_at=? WHERE user_id IN (${target}) AND created_at<=? AND ${pending}`,
            ).bind(now(), event.subject, event.time, event.time, event.id),
        ];
        if (event.type === "consent-revoked") {
            statements.push(
                env.DB.prepare(
                    `UPDATE users SET apple_refresh_cipher=NULL WHERE apple_subject=? AND apple_authorized_at<=? AND ${pending}`,
                ).bind(event.subject, event.time, event.id),
            );
        } else {
            statements.push(
                env.DB.prepare(
                    `UPDATE submissions SET source='',hidden_at=? WHERE user_id IN (${target}) AND ${pending}`,
                ).bind(now(), event.subject, event.time, event.id),
            );
            statements.push(
                env.DB.prepare(
                    `UPDATE users SET status='deleted',apple_subject=NULL,apple_refresh_cipher=NULL,display_name='Deleted user',deleted_at=? WHERE user_id IN (${target}) AND ${pending}`,
                ).bind(now(), event.subject, event.time, event.id),
            );
        }
        statements.push(
            env.DB.prepare(
                "UPDATE apple_events SET handled_at=? WHERE event_id=? AND handled_at IS NULL",
            ).bind(now(), event.id),
        );
        // The batch is atomic; duplicate deliveries cannot revoke a later sign-in.
        await env.DB.batch(statements);
        return json({ ok: true });
    }
    if (method === "POST" && path === "/v1/auth/challenge") {
        await rateLimit(env, `login:${ipKey}`, 10);
        const id = crypto.randomUUID(),
            nonce = randomToken();
        await env.DB.prepare(
            "INSERT INTO challenges(challenge_id,nonce_hash,expires_at) VALUES(?,?,?)",
        )
            .bind(id, await hash(nonce), now() + 300)
            .run();
        return json({ challenge_id: id, nonce });
    }
    if (method === "POST" && path === "/v1/auth/apple") {
        await rateLimit(env, `login:${ipKey}`, 10);
        const data = await body(request),
            id = string(data, "challenge_id", 64),
            nonce = string(data, "nonce", 128);
        const challenge = await env.DB.prepare(
            "DELETE FROM challenges WHERE challenge_id=? AND expires_at>? RETURNING nonce_hash",
        )
            .bind(id, now())
            .first<{ nonce_hash: string }>();
        if (!challenge || challenge.nonce_hash !== (await hash(nonce)))
            throw new HTTPError(401, "Login challenge expired");
        const subject = await verifyApple(
            string(data, "identity_token"),
            env,
            nonce,
        );
        const exchange = await exchangeApple(
            string(data, "authorization_code"),
            env,
        );
        if (exchange.subject !== subject)
            throw new HTTPError(401, "Apple identity mismatch");
        const cipher = await seal(exchange.refresh, env),
            userID = crypto.randomUUID();
        await env.DB.prepare(
            `INSERT INTO users(user_id,apple_subject,display_name,apple_refresh_cipher,created_at,apple_authorized_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(apple_subject) DO UPDATE SET apple_refresh_cipher=excluded.apple_refresh_cipher,apple_authorized_at=excluded.apple_authorized_at WHERE users.status!='deleted'`,
        )
            .bind(
                userID,
                subject,
                `Learner ${userID.slice(0, 8)}`,
                cipher,
                now(),
                now(),
            )
            .run();
        const user = await env.DB.prepare(
            "SELECT user_id,display_name FROM users WHERE apple_subject=? AND status!='deleted'",
        )
            .bind(subject)
            .first<{ user_id: string; display_name: string }>();
        if (!user) throw new HTTPError(403, "Account unavailable");
        return json({ ...(await newSession(env, user.user_id)), user });
    }
    if (method === "POST" && path === "/v1/auth/refresh") {
        const data = await body(request),
            oldHash = await hash(string(data, "refresh_token", 128)),
            refresh = randomToken();
        // CAS consumes the old token exactly once, including concurrent refreshes.
        const session = await env.DB.prepare(
            `UPDATE sessions SET refresh_hash=? WHERE refresh_hash=? AND revoked_at IS NULL AND expires_at>?
      AND user_id IN (SELECT user_id FROM users WHERE status!='deleted') RETURNING session_id,user_id`,
        )
            .bind(await hash(refresh), oldHash, now())
            .first<{ session_id: string; user_id: string }>();
        if (!session) throw new HTTPError(401, "Session expired");
        return json({
            access_token: await accessToken(
                session.user_id,
                session.session_id,
                env,
            ),
            refresh_token: refresh,
            expires_at: now() + 900,
        });
    }
    if (method === "GET" && path === "/v1/problems/bests") {
        const puzzles = await catalog;
        const valid = JSON.stringify(
            puzzles.map((p) => [p.id, p.puzzle_version]),
        );
        const data = await env.DB.prepare(
            `WITH current_puzzles(problem_id,puzzle_version) AS (
              SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]') FROM json_each(?))
            SELECT s.problem_id,s.puzzle_version,MIN(s.bytes) bytes
            FROM submissions s JOIN current_puzzles p
              ON s.problem_id=p.problem_id AND s.puzzle_version=p.puzzle_version
              JOIN users u ON u.user_id=s.user_id
            WHERE s.accepted=1 AND s.hidden_at IS NULL AND s.rules_version=? AND u.status='active'
            GROUP BY s.problem_id,s.puzzle_version ORDER BY s.problem_id`,
        )
            .bind(valid, RULES_VERSION)
            .all();
        return json({ rules_version: RULES_VERSION, entries: data.results });
    }
    const problemRanking = path.match(/^\/v1\/problems\/(\d+)\/leaderboard$/);
    if (method === "GET" && problemRanking) {
        const puzzle = (await catalog).find(
            (p) => p.id === Number(problemRanking[1]),
        );
        if (!puzzle) throw new HTTPError(404, "Unknown problem");
        const limit = Math.floor(
            Math.max(
                1,
                Math.min(100, Number(url.searchParams.get("limit")) || 50),
            ),
        );
        const data = await env.DB.prepare(
            `WITH attempts AS (
              SELECT s.user_id,u.display_name,s.points,s.bytes,s.accepted,s.lit_targets,s.target_count,s.steps,
                ROW_NUMBER() OVER(PARTITION BY s.user_id ORDER BY s.points DESC,s.bytes,s.steps,s.created_at,s.submission_id) attempt
              FROM submissions s JOIN users u ON u.user_id=s.user_id
              WHERE s.problem_id=? AND s.puzzle_version=? AND s.rules_version=? AND s.hidden_at IS NULL AND u.status='active')
            SELECT ROW_NUMBER() OVER(ORDER BY points DESC,bytes,user_id) rank,
              user_id,display_name,points,bytes,accepted,lit_targets,target_count,steps
            FROM attempts WHERE attempt=1 ORDER BY points DESC,bytes,user_id LIMIT ?`,
        )
            .bind(puzzle.id, puzzle.puzzle_version, RULES_VERSION, limit)
            .all();
        return json({
            problem_id: puzzle.id,
            puzzle_version: puzzle.puzzle_version,
            entries: data.results,
        });
    }
    if (method === "GET" && path === "/v1/leaderboard") {
        const limit = Math.max(
            1,
            Math.min(100, Number(url.searchParams.get("limit")) || 50),
        );
        const puzzles = await catalog;
        const valid = JSON.stringify(
            puzzles.map((p) => [p.id, p.puzzle_version]),
        );
        const data = await env.DB.prepare(
            `WITH current_puzzles(problem_id,puzzle_version) AS (
              SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]') FROM json_each(?)),
      best AS (SELECT s.user_id,s.problem_id,MAX(s.points) points,MAX(s.accepted) accepted FROM submissions s JOIN current_puzzles p
      ON s.problem_id=p.problem_id AND s.puzzle_version=p.puzzle_version WHERE s.hidden_at IS NULL AND s.rules_version=? GROUP BY s.user_id,s.problem_id),
      totals AS (SELECT u.user_id,u.display_name,ROUND(SUM(b.points),2) points,SUM(b.accepted) solved FROM best b JOIN users u ON u.user_id=b.user_id WHERE u.status='active' GROUP BY u.user_id)
      SELECT ROW_NUMBER() OVER(ORDER BY points DESC,solved DESC,user_id) rank,*,ROUND(points/?,2) percentage FROM totals ORDER BY points DESC,solved DESC,user_id LIMIT ?`,
        )
            .bind(valid, RULES_VERSION, puzzles.length, Math.floor(limit))
            .all();
        return json({
            rules_version: RULES_VERSION,
            puzzle_count: puzzles.length,
            entries: data.results,
        });
    }
    if (!path.startsWith("/v1/")) throw new HTTPError(404, "Not found");
    const user = await authenticate(request, env);
    if (method === "GET" && path === "/v1/me")
        return json({ user_id: user.user_id, display_name: user.display_name });
    if (method === "PATCH" && path === "/v1/me") {
        await rateLimit(env, `profile:${user.user_id}`, 10);
        const data = await body(request);
        const name = string(data, "display_name", 256).normalize("NFC").trim();
        if (!name || [...name].length > 32 || /[\p{Cc}\p{Cf}]/u.test(name))
            throw new HTTPError(
                400,
                "Display name must contain 1–32 characters without control characters",
            );
        await env.DB.prepare("UPDATE users SET display_name=? WHERE user_id=?")
            .bind(name, user.user_id)
            .run();
        return json({ user_id: user.user_id, display_name: name });
    }
    if (method === "POST" && path === "/v1/auth/logout") {
        await env.DB.prepare(
            "UPDATE sessions SET revoked_at=? WHERE session_id=?",
        )
            .bind(now(), user.session_id)
            .run();
        return json({ ok: true });
    }
    if (method === "DELETE" && path === "/v1/me") {
        await env.DB.batch([
            env.DB.prepare(
                "INSERT OR IGNORE INTO apple_revocations(revocation_id,cipher,next_attempt_at,created_at) SELECT ?,apple_refresh_cipher,?,? FROM users WHERE user_id=? AND apple_refresh_cipher IS NOT NULL AND status!='deleted'",
            ).bind(crypto.randomUUID(), now(), now(), user.user_id),
            env.DB.prepare(
                "UPDATE users SET status='deleted',apple_subject=NULL,apple_refresh_cipher=NULL,display_name='Deleted user',deleted_at=? WHERE user_id=?",
            ).bind(now(), user.user_id),
            env.DB.prepare(
                "UPDATE sessions SET revoked_at=? WHERE user_id=?",
            ).bind(now(), user.user_id),
            env.DB.prepare(
                "UPDATE submissions SET source='',hidden_at=? WHERE user_id=?",
            ).bind(now(), user.user_id),
        ]);
        return json({ ok: true });
    }
    if (method === "GET" && path === "/v1/me/submissions") {
        const results = await env.DB.prepare(
            "SELECT submission_id,problem_id,puzzle_version,bytes,steps,lit_targets,target_count,points,accepted,created_at FROM submissions WHERE user_id=? ORDER BY created_at DESC LIMIT 100",
        )
            .bind(user.user_id)
            .all();
        return json({ submissions: results.results });
    }
    if (method === "POST" && path === "/v1/submissions") {
        await rateLimit(env, `submit:${user.user_id}`, 60);
        const data = await body(request),
            id = string(data, "request_id", 64),
            version = string(data, "puzzle_version", 64),
            source = string(data, "source", 16384);
        if (!Number.isInteger(data.problem_id))
            throw new HTTPError(400, "Invalid problem_id");
        const puzzle = (await catalog).find((p) => p.id === data.problem_id);
        if (!puzzle || puzzle.puzzle_version !== version)
            throw new HTTPError(409, "Puzzle version is not supported");
        const prior = await env.DB.prepare(
            "SELECT * FROM submissions WHERE user_id=? AND request_id=?",
        )
            .bind(user.user_id, id)
            .first();
        if (prior) {
            if (
                prior.problem_id !== puzzle.id ||
                prior.puzzle_version !== version ||
                prior.source !== source
            )
                throw new HTTPError(
                    409,
                    "Request ID reused with different content",
                );
            return json({
                submission_id: prior.submission_id,
                accepted: prior.accepted === 1,
                bytes: prior.bytes,
                steps: prior.steps,
                lit_targets: prior.lit_targets,
                target_count: prior.target_count,
                points: prior.points,
                feedback: "Previously evaluated",
            });
        }
        const evaluation = evaluate(source, puzzle),
            submissionID = crypto.randomUUID();
        // Concurrent retries may race; uniqueness makes their result idempotent.
        await env.DB.prepare(
            `INSERT INTO submissions(submission_id,user_id,request_id,problem_id,puzzle_version,rules_version,source,bytes,steps,lit_targets,target_count,points,accepted,created_at)
      SELECT ?,?,?,?,?,?,?,?,?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM users WHERE user_id=? AND status='active') ON CONFLICT(user_id,request_id) DO NOTHING`,
        )
            .bind(
                submissionID,
                user.user_id,
                id,
                puzzle.id,
                version,
                RULES_VERSION,
                source,
                evaluation.bytes,
                evaluation.steps,
                evaluation.litTargets,
                evaluation.targetCount,
                evaluation.points,
                Number(evaluation.accepted),
                now(),
                user.user_id,
            )
            .run();
        const stored = await env.DB.prepare(
            "SELECT submission_id,source,problem_id,puzzle_version FROM submissions WHERE user_id=? AND request_id=?",
        )
            .bind(user.user_id, id)
            .first<{
                submission_id: string;
                source: string;
                problem_id: number;
                puzzle_version: string;
            }>();
        if (
            !stored ||
            stored.source !== source ||
            stored.problem_id !== puzzle.id ||
            stored.puzzle_version !== version
        )
            throw new HTTPError(409, "Request ID conflict");
        return json({
            submission_id: stored.submission_id,
            accepted: evaluation.accepted,
            bytes: evaluation.bytes,
            steps: evaluation.steps,
            lit_targets: evaluation.litTargets,
            target_count: evaluation.targetCount,
            points: evaluation.points,
            feedback: evaluation.feedback,
        });
    }
    throw new HTTPError(404, "Not found");
}
async function admin(request: Request, env: Env, path: string) {
    const actor = await authenticateAdmin(request, env);
    if (request.method === "GET" && path === "/admin/v1/users") {
        return json({
            users: (
                await env.DB.prepare(
                    "SELECT user_id,display_name,status,created_at FROM users ORDER BY created_at DESC LIMIT 100",
                ).all()
            ).results,
        });
    }
    if (request.method === "GET" && path === "/admin/v1/submissions") {
        return json({
            submissions: (
                await env.DB.prepare(
                    "SELECT s.* FROM submissions s JOIN users u ON u.user_id=s.user_id WHERE u.status!='deleted' ORDER BY s.created_at DESC LIMIT 100",
                ).all()
            ).results,
        });
    }
    const match = /^\/admin\/v1\/(users|submissions)\/([a-zA-Z0-9-]+)$/.exec(
        path,
    );
    if (request.method !== "PATCH" || !match)
        throw new HTTPError(404, "Not found");
    const data = await body(request),
        reason = string(data, "reason", 500),
        id = match[2];
    let statement: D1PreparedStatement, action: string;
    if (match[1] === "users") {
        const status = string(data, "status", 10);
        if (!["active", "blocked"].includes(status))
            throw new HTTPError(400, "Invalid status");
        const found = await env.DB.prepare(
            "SELECT user_id FROM users WHERE user_id=? AND status!='deleted'",
        )
            .bind(id)
            .first();
        if (!found) throw new HTTPError(404, "User not found");
        statement = env.DB.prepare(
            "UPDATE users SET status=? WHERE user_id=? AND status!='deleted'",
        ).bind(status, id);
        action = `user.${status}`;
    } else {
        if (typeof data.hidden !== "boolean")
            throw new HTTPError(400, "Invalid hidden");
        const found = await env.DB.prepare(
            "SELECT submission_id FROM submissions WHERE submission_id=?",
        )
            .bind(id)
            .first();
        if (!found) throw new HTTPError(404, "Submission not found");
        statement = env.DB.prepare(
            "UPDATE submissions SET hidden_at=? WHERE submission_id=?",
        ).bind(data.hidden ? now() : null, id);
        action = data.hidden ? "submission.hide" : "submission.restore";
    }
    const statements = [
        statement,
        env.DB.prepare(
            "INSERT INTO admin_audit(audit_id,actor,action,target_id,reason,created_at) VALUES(?,?,?,?,?,?)",
        ).bind(crypto.randomUUID(), actor, action, id, reason, now()),
    ];
    if (action === "user.blocked")
        statements.push(
            env.DB.prepare(
                "UPDATE sessions SET revoked_at=? WHERE user_id=?",
            ).bind(now(), id),
        );
    await env.DB.batch(statements);
    return json({ ok: true });
}
