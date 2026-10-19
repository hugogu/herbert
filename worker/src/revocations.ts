import { type Env, HTTPError, now, revokeApple } from "./auth";

const maximumAttempts = 8;

// A failed external revocation must never prevent local account erasure.
export async function drainRevocations(env: Env) {
    const due = await env.DB.prepare(
        "SELECT revocation_id FROM apple_revocations WHERE status='pending' AND next_attempt_at<=? AND lease_until<=? ORDER BY next_attempt_at LIMIT 10",
    )
        .bind(now(), now())
        .all<{ revocation_id: string }>();
    for (const item of due.results) {
        const job = await env.DB.prepare(
            "UPDATE apple_revocations SET attempts=attempts+1,lease_until=? WHERE revocation_id=? AND status='pending' AND lease_until<=? AND next_attempt_at<=? RETURNING cipher,attempts",
        )
            .bind(now() + 120, item.revocation_id, now(), now())
            .first<{ cipher: string; attempts: number }>();
        if (!job) continue;
        let status = "revoked";
        try {
            if (job.attempts > maximumAttempts) status = "exhausted";
            else await revokeApple(job.cipher, env);
        } catch (error) {
            // Revocation transport/configuration errors are retriable. Ciphertexts
            // that no longer decrypt after key rotation cannot be recovered.
            status =
                error instanceof HTTPError
                    ? job.attempts < maximumAttempts
                        ? "pending"
                        : "exhausted"
                    : "unrevocable";
            console.warn(
                JSON.stringify({
                    event: "apple_revocation_failed",
                    reference: item.revocation_id,
                    status,
                    attempt: job.attempts,
                }),
            );
        }
        await env.DB.prepare(
            "UPDATE apple_revocations SET status=?,cipher=?,next_attempt_at=?,lease_until=0,finished_at=? WHERE revocation_id=?",
        )
            .bind(
                status,
                status === "pending" ? job.cipher : null,
                now() + Math.min(21600, 60 * 2 ** (job.attempts - 1)),
                status === "pending" ? null : now(),
                item.revocation_id,
            )
            .run();
    }
}
