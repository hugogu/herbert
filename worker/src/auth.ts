import {
    createRemoteJWKSet,
    errors,
    importPKCS8,
    jwtVerify,
    SignJWT,
} from "jose";
export interface Env {
    DB: D1Database;
    APPLE_CLIENT_ID: string;
    APPLE_TEAM_ID: string;
    APPLE_KEY_ID: string;
    APPLE_PRIVATE_KEY: string;
    SESSION_SECRET: string;
    TOKEN_ENCRYPTION_KEY: string;
    TOKEN_ISSUER: string;
    ADMIN_ISSUER: string;
    ADMIN_AUDIENCE: string;
    ADMIN_EMAILS: string;
}
export class HTTPError extends Error {
    constructor(
        readonly status: number,
        message: string,
    ) {
        super(message);
    }
}
export function appleFailure(status: number, code: string, hint: string) {
    const reference = crypto.randomUUID();
    // Never log the original exception: JOSE errors can contain identity claims.
    console.warn(
        JSON.stringify({ event: "apple_auth_failed", code, reference }),
    );
    return new HTTPError(status, `${hint} [${code}; reference: ${reference}]`);
}

export function appleIdentityFailure(error: unknown): HTTPError {
    if (error instanceof errors.JWTExpired)
        return appleFailure(
            401,
            "apple_token_expired",
            "Apple identity expired; sign in again",
        );
    if (error instanceof errors.JWTClaimValidationFailed) {
        if (error.claim === "aud")
            return appleFailure(
                401,
                "apple_audience_mismatch",
                "Apple app identity does not match APPLE_CLIENT_ID; check the app Bundle ID and Worker environment",
            );
        return appleFailure(
            401,
            "apple_claim_invalid",
            "Apple identity claims are invalid; sign in again and check the system clock",
        );
    }
    if (
        error instanceof errors.JWSSignatureVerificationFailed ||
        error instanceof errors.JWKSNoMatchingKey
    )
        return appleFailure(
            401,
            "apple_signature_invalid",
            "Apple identity signature could not be verified",
        );
    if (
        error instanceof errors.JWTInvalid ||
        error instanceof errors.JWSInvalid ||
        error instanceof errors.JOSEAlgNotAllowed ||
        error instanceof errors.JOSENotSupported
    )
        return appleFailure(
            401,
            "apple_token_invalid",
            "Apple identity token is malformed or unsupported",
        );
    return appleFailure(
        503,
        "apple_keys_unavailable",
        "Apple signing keys could not be loaded; check Worker network, DNS and proxy access to appleid.apple.com, then retry",
    );
}

export const now = () => Math.floor(Date.now() / 1000);
export const randomToken = () =>
    [...crypto.getRandomValues(new Uint8Array(32))]
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
export async function hash(text: string) {
    return [
        ...new Uint8Array(
            await crypto.subtle.digest(
                "SHA-256",
                new TextEncoder().encode(text),
            ),
        ),
    ]
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}
const appleKeys = createRemoteJWKSet(
    new URL("https://appleid.apple.com/auth/keys"),
);
function sessionKey(env: Env) {
    if (!env.SESSION_SECRET || env.SESSION_SECRET.length < 32)
        throw new HTTPError(503, "Authentication is not configured");
    return new TextEncoder().encode(env.SESSION_SECRET);
}
export async function verifyApple(token: string, env: Env, nonce?: string) {
    if (!env.APPLE_CLIENT_ID)
        throw appleFailure(
            503,
            "apple_client_id_missing",
            "Set APPLE_CLIENT_ID to the app Bundle ID",
        );
    let payload;
    try {
        ({ payload } = await jwtVerify(token, appleKeys, {
            issuer: "https://appleid.apple.com",
            audience: env.APPLE_CLIENT_ID,
            algorithms: ["RS256"],
            maxTokenAge: "10m",
        }));
    } catch (error) {
        throw appleIdentityFailure(error);
    }
    if (!payload.sub)
        throw appleFailure(
            401,
            "apple_subject_missing",
            "Apple identity has no subject",
        );
    if (nonce !== undefined && payload.nonce !== nonce)
        throw appleFailure(
            401,
            "apple_nonce_mismatch",
            "Apple login challenge does not match; sign in again",
        );
    return payload.sub;
}
export async function appleNotification(token: string, env: Env) {
    try {
        const { payload } = await jwtVerify(token, appleKeys, {
            issuer: "https://appleid.apple.com",
            audience: env.APPLE_CLIENT_ID,
            algorithms: ["RS256"],
        });
        const event =
            typeof payload.events === "string"
                ? JSON.parse(payload.events)
                : payload.events;
        if (
            !event ||
            typeof event.type !== "string" ||
            typeof event.sub !== "string" ||
            event.sub.length > 255 ||
            !Number.isInteger(event.event_time) ||
            event.event_time < 0 ||
            event.event_time > now() + 300
        )
            throw new Error("Invalid event");
        return {
            id: await hash(token),
            type: event.type as string,
            subject: event.sub as string,
            time: event.event_time as number,
        };
    } catch {
        throw new HTTPError(401, "Invalid Apple notification");
    }
}
async function appleSecret(env: Env) {
    if (!env.APPLE_TEAM_ID || !env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY)
        throw appleFailure(
            503,
            "apple_credentials_missing",
            "Set APPLE_TEAM_ID, APPLE_KEY_ID and APPLE_PRIVATE_KEY on the Worker",
        );
    let key;
    try {
        key = await importPKCS8(
            env.APPLE_PRIVATE_KEY.replace(/\\n/g, "\n"),
            "ES256",
        );
    } catch {
        throw appleFailure(
            503,
            "apple_private_key_invalid",
            "APPLE_PRIVATE_KEY must contain the full Sign in with Apple P8 PEM, not its filename",
        );
    }
    return new SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID })
        .setIssuer(env.APPLE_TEAM_ID)
        .setSubject(env.APPLE_CLIENT_ID)
        .setAudience("https://appleid.apple.com")
        .setIssuedAt()
        .setExpirationTime("5m")
        .sign(key);
}
async function appleRequest(
    env: Env,
    endpoint: "token" | "revoke",
    fields: Record<string, string>,
) {
    const body = new URLSearchParams({
        client_id: env.APPLE_CLIENT_ID,
        client_secret: await appleSecret(env),
        ...fields,
    });
    let response;
    try {
        response = await fetch(`https://appleid.apple.com/auth/${endpoint}`, {
            method: "POST",
            body,
            signal: AbortSignal.timeout(15000),
        });
    } catch {
        throw appleFailure(
            503,
            "apple_service_unavailable",
            "Apple authorization service is unreachable; check Worker network and proxy settings",
        );
    }
    if (!response.ok) {
        const data = await response
            .json<{ error?: string }>()
            .catch(() => null);
        if (data?.error === "invalid_client")
            throw appleFailure(
                503,
                "apple_client_invalid",
                "Apple rejected the Worker credentials; check APPLE_CLIENT_ID, TEAM_ID, KEY_ID and the Sign in with Apple P8 key association",
            );
        if (endpoint === "token" && data?.error === "invalid_grant")
            throw appleFailure(
                401,
                "apple_code_invalid",
                "Apple authorization code expired or was already used; sign in again",
            );
        throw appleFailure(
            503,
            "apple_authorization_failed",
            "Apple authorization could not be completed; retry later",
        );
    }
    return response;
}
export async function exchangeApple(code: string, env: Env) {
    const data = await (
        await appleRequest(env, "token", {
            grant_type: "authorization_code",
            code,
        })
    ).json<{ id_token?: string; refresh_token?: string }>();
    if (!data.id_token || !data.refresh_token)
        throw new HTTPError(401, "Incomplete Apple authorization");
    return {
        subject: await verifyApple(data.id_token, env),
        refresh: data.refresh_token,
    };
}
async function encryptionKey(env: Env) {
    if (!env.TOKEN_ENCRYPTION_KEY)
        throw new HTTPError(503, "Token encryption is not configured");
    const bytes = Uint8Array.from(atob(env.TOKEN_ENCRYPTION_KEY), (c) =>
        c.charCodeAt(0),
    );
    if (bytes.length !== 32)
        throw new HTTPError(503, "Token encryption is not configured");
    return crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
        "encrypt",
        "decrypt",
    ]);
}
export async function seal(text: string, env: Env) {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const cipher = new Uint8Array(
        await crypto.subtle.encrypt(
            { name: "AES-GCM", iv },
            await encryptionKey(env),
            new TextEncoder().encode(text),
        ),
    );
    return btoa(String.fromCharCode(...iv, ...cipher));
}
export async function unseal(text: string, env: Env) {
    const bytes = Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
    return new TextDecoder().decode(
        await crypto.subtle.decrypt(
            { name: "AES-GCM", iv: bytes.slice(0, 12) },
            await encryptionKey(env),
            bytes.slice(12),
        ),
    );
}
export async function revokeApple(cipher: string, env: Env) {
    await appleRequest(env, "revoke", {
        token: await unseal(cipher, env),
        token_type_hint: "refresh_token",
    });
}
export async function accessToken(userID: string, sessionID: string, env: Env) {
    return new SignJWT({ sid: sessionID })
        .setProtectedHeader({ alg: "HS256" })
        .setIssuer(env.TOKEN_ISSUER)
        .setAudience("herbert-api")
        .setSubject(userID)
        .setIssuedAt()
        .setExpirationTime("15m")
        .sign(sessionKey(env));
}
export async function authenticate(request: Request, env: Env) {
    const token = request.headers
        .get("Authorization")
        ?.match(/^Bearer (.+)$/)?.[1];
    if (!token) throw new HTTPError(401, "Sign in required");
    let payload;
    try {
        payload = (
            await jwtVerify(token, sessionKey(env), {
                issuer: env.TOKEN_ISSUER,
                audience: "herbert-api",
                algorithms: ["HS256"],
            })
        ).payload;
    } catch (e) {
        if (e instanceof HTTPError) throw e;
        throw new HTTPError(401, "Session expired");
    }
    if (typeof payload.sid !== "string" || !payload.sub)
        throw new HTTPError(401, "Invalid session");
    const user = await env.DB.prepare(
        `SELECT u.user_id, u.display_name, u.apple_refresh_cipher, u.status, s.session_id FROM users u JOIN sessions s ON u.user_id=s.user_id
    WHERE s.session_id=? AND u.user_id=? AND u.status!='deleted' AND s.revoked_at IS NULL AND s.expires_at>?`,
    )
        .bind(payload.sid, payload.sub, now())
        .first<{
            user_id: string;
            display_name: string;
            apple_refresh_cipher: string;
            status: string;
            session_id: string;
        }>();
    if (!user)
        throw new HTTPError(401, "Session expired or account unavailable");
    const path = new URL(request.url).pathname;
    if (
        user.status === "blocked" &&
        !["/v1/me", "/v1/auth/logout"].includes(path)
    )
        throw new HTTPError(403, "Account is blocked from submitting");
    return user;
}
export async function authenticateAdmin(request: Request, env: Env) {
    if (
        !/^https:\/\/[a-z0-9-]+\.cloudflareaccess\.com$/.test(
            env.ADMIN_ISSUER,
        ) ||
        !env.ADMIN_AUDIENCE ||
        !env.ADMIN_EMAILS
    )
        throw new HTTPError(403, "Administration is disabled");
    const token = request.headers.get("Cf-Access-Jwt-Assertion");
    if (!token)
        throw new HTTPError(403, "Administrator authentication required");
    try {
        const keys = createRemoteJWKSet(
            new URL(`${env.ADMIN_ISSUER}/cdn-cgi/access/certs`),
        );
        const { payload } = await jwtVerify(token, keys, {
            issuer: env.ADMIN_ISSUER,
            audience: env.ADMIN_AUDIENCE,
            algorithms: ["RS256"],
        });
        if (
            typeof payload.email !== "string" ||
            !env.ADMIN_EMAILS.split(",")
                .map((v) => v.trim().toLowerCase())
                .includes(payload.email.toLowerCase())
        )
            throw new Error("Not an administrator");
        return payload.email;
    } catch {
        throw new HTTPError(403, "Administrator access denied");
    }
}
