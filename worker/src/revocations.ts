import { type Env, HTTPError, now, revokeApple } from "./auth";

const maximumAttempts = 10;
const maximumAge = 7 * 86400;
const configurationErrors = new Set([
    "apple_credentials_missing",
    "apple_private_key_invalid",
    "apple_client_invalid",
    "token_encryption_missing",
    "token_encryption_invalid",
]);

// A failed external revocation must never prevent local account erasure.
export async function drainRevocations(env: Env) {
    const due = await env.DB.prepare(
        "SELECT revocation_id FROM apple_revocations WHERE status='pending' AND next_attempt_at<=? AND lease_until<=? ORDER BY next_attempt_at LIMIT 10",
    )
        .bind(now(), now())
        .all<{ revocation_id: string }>();
    for (const item of due.results) {
        const job = await env.DB.prepare(
            "UPDATE apple_revocations SET attempts=attempts+1,lease_until=? WHERE revocation_id=? AND status='pending' AND lease_until<=? AND next_attempt_at<=? RETURNING cipher,attempts,created_at",
        )
            .bind(now() + 120, item.revocation_id, now(), now())
            .first<{ cipher: string; attempts: number; created_at: number }>();
        if (!job) continue;
        let status = "revoked";
        let attempts = job.attempts;
        const expiresAt = job.created_at + maximumAge;
        let nextAttempt = now() + Math.min(86400, 900 * 2 ** (attempts - 1));
        if (now() >= expiresAt || attempts > maximumAttempts) {
            status = "exhausted";
            attempts--;
            console.error(
                JSON.stringify({
                    event: "apple_revocation_expired",
                    reference: item.revocation_id,
                    attempt: attempts,
                }),
            );
        } else {
            try {
                await revokeApple(job.cipher, env);
            } catch (error) {
                if (
                    error instanceof HTTPError &&
                    configurationErrors.has(error.code ?? "")
                ) {
                    // Operator-fixable outages do not consume the retry allowance.
                    attempts--;
                    status = "pending";
                    nextAttempt = now() + 3600;
                    console.error(
                        JSON.stringify({
                            event: "apple_revocation_configuration_error",
                            code: error.code,
                            reference: item.revocation_id,
                            attempt: attempts,
                        }),
                    );
                } else {
                    status =
                        error instanceof HTTPError
                            ? attempts < maximumAttempts
                                ? "pending"
                                : "exhausted"
                            : "unrevocable";
                    console.warn(
                        JSON.stringify({
                            event: "apple_revocation_failed",
                            reference: item.revocation_id,
                            status,
                            attempt: attempts,
                        }),
                    );
                }
            }
        }
        await env.DB.prepare(
            "UPDATE apple_revocations SET status=?,cipher=?,attempts=?,next_attempt_at=?,lease_until=0,finished_at=? WHERE revocation_id=?",
        )
            .bind(
                status,
                status === "pending" ? job.cipher : null,
                attempts,
                Math.min(expiresAt, nextAttempt),
                status === "pending" ? null : now(),
                item.revocation_id,
            )
            .run();
    }
}
