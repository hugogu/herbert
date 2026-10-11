import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
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
    const { payload } = await jwtVerify(token, appleKeys, {
        issuer: "https://appleid.apple.com",
        audience: env.APPLE_CLIENT_ID,
        algorithms: ["RS256"],
        maxTokenAge: "10m",
    });
    if (!payload.sub || (nonce !== undefined && payload.nonce !== nonce))
        throw new HTTPError(401, "Invalid Apple identity");
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
        throw new HTTPError(503, "Apple authentication is not configured");
    const key = await importPKCS8(
        env.APPLE_PRIVATE_KEY.replace(/\\n/g, "\n"),
        "ES256",
    );
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
    const response = await fetch(`https://appleid.apple.com/auth/${endpoint}`, {
        method: "POST",
        body,
        signal: AbortSignal.timeout(15000),
    });
    if (!response.ok)
        throw new HTTPError(
            endpoint === "token" && response.status === 400 ? 401 : 503,
            "Apple authorization could not be completed",
        );
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
