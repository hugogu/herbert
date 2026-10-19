# Verified cloud leaderboards

Herbert's optional online service runs on Cloudflare Workers and D1. Local play,
progress backups and drafts do not depend on it. This is a separate service from
AI Battlefield: the public leaderboard ranks users' H programs, not self-reported
model tokens or benchmark timings. Only the 50 MIT-original exercises are scored.

## Trust and data boundaries

The native App Store app uses Sign in with Apple without requesting email. It
requests an optional full name, which Apple normally returns only on first
authorization, to prefill the public nickname editor. The name stays on-device
until the user explicitly saves it; existing users can choose an alias without
reauthorizing Apple. `PATCH /v1/me` updates only the authenticated user's nickname
(1–32 Unicode code points, NFC-normalized, no control/format characters), with
rate limiting. Nicknames are public labels, not verified identities or unique
usernames; duplicates do not merge accounts or change scores.
The Worker verifies Apple's signature, issuer, audience, expiry and a single-use
nonce, exchanges the authorization code, then binds the verified Apple subject to
an internal UUID. It issues a 15-minute JWT and a rotating, 30-day session refresh
token. JWTs carry a session ID; every authenticated operation checks that session
and account in D1, so logout and blocking take effect immediately.

The app stores its session in device-only Keychain. D1 stores only SHA-256 hashes
of Herbert refresh tokens. Apple's refresh credential is encrypted using AES-GCM
so the service can revoke Apple authorization when an account is deleted. No
Cloudflare credential or Apple private key belongs in an app, save file or repo.

The **My** tab follows AI Battlefield and has separate **Progress** and **Account**
sections. Progress contains backups, local completion records and the global
leaderboard entry. Account owns
Apple sign-in, public nickname editing, sign-out/deletion and batch upload of
saved solutions through **Upload & Share my Solutions**. The upload area shows
how many original puzzles have a saved answer; it sends one locally retained
solution per puzzle, excluding drafts and community puzzles. This account state
is shared with puzzle pages. Leaderboard uploads publish scores, not a backup or
cross-device synchronization of practice records.

After an original puzzle's program finishes, **Upload this answer** uploads
that executed source snapshot (including incomplete attempts). If
signed out, Apple sign-in opens and the requested upload resumes after login;
canceling login cancels the pending upload. Editing or resetting the program
hides its upload action until another run finishes. AI trial pages and community
puzzles do not offer this upload action. Opening a ranking never requires login.
**Ranking**, next to **Details** and **Rules** in the game header, opens that puzzle's leaderboard; **My → Progress → Global
leaderboard** opens the overall ranking, with a selector for individual puzzles.
Puzzle pages show the shortest accepted online answer size in the same reference
row used for archived community records. Per-puzzle rankings include lit targets,
size and executed instructions. **My → Progress → Best solutions** counts locally
saved accepted answers whose size matches or improves a known shortest record,
including ties; score and instructions do not affect this count. Original records
come from all visible, active, current-version accepted submissions, independently
of ranking position or page limits. Community references are the archived site
records, not live records. Unknown records are excluded; a failed initial online
load shows an unavailable count rather than zero. Uploads refresh online references.
Community solutions and AI provider keys are never uploaded. Failed uploads leave the local solutions intact; the
user can retry. Uploads are sequential and limited to 60 per user per minute, enough for the full course. Public results contain
only a public nickname, scores and completion/answer-length metrics; source programs are
available to the owner/admin, not anonymously published.

`POST /v1/submissions` accepts only a request ID, problem ID, puzzle version and H
source. The Worker loads its own canonical board and byte limit, compiles and runs
the program, and calculates verified points: partial answers earn 80 × target coverage; only accepted answers earn the length bonus, 80 + 20 × (1 − bytes / limit). Migration 0004 recalculates legacy partial scores. AI Battlefield keeps its separately versioned benchmark scoring policy. Client scores, target
counts, user IDs and timestamps are ignored. Limits match the native judge:
16 KiB source, 64 argument nesting, 128 expanded nesting, 4,096 frames, one million
expansions/steps, bounded pending memory and ten million cumulative expansion-work units in both Swift and the Worker. Copying and validation consume this budget across the entire run, including tail calls. The 76 accepted native differential fixtures peak at 1,282 units (over 7,800× headroom); the reported growing-argument attack is covered in both VMs. Local timing is diagnostic only, not a deployed Worker CPU guarantee. Walls leave the robot in place;
traps clear all lit targets. Success stops execution immediately.

Puzzle identity is SHA-256 of `herbert-h-v1\n{id}\n{byteLimit}\n{rows joined by \n}`.
Retired/revised boards cannot inherit current scores. Rankings use each user's
best non-hidden attempt per current puzzle, sum the points, then divide by the current puzzle count (50) for
a percentage. An accepted answer always takes precedence over an incomplete attempt for the same puzzle.
Per-puzzle ties use points, shorter code, fewer executed instructions, then earlier server submission time;
user ID is only a final deterministic fallback. Aggregate ties use solved count, fewer total instructions,
then the time the selected results were achieved. Total points and solved count always come from the
same selected attempts; client timing cannot influence standings.

Migration 0004 maintains `best_submissions` atomically using submission triggers, including hide/restore,
version changes and account erasure. Rankings scan one selected row per player/puzzle/version rather than
all historical attempts; the independent minimum accepted size is retained for reference displays.
Public rows never include source programs. Results reflect program quality, not whether a human or AI authored it.

The client derives submission request IDs from SHA-256 of the puzzle version, newline and exact source.
Single uploads, retries and batch uploads reuse the same identity; changed boards or programs get a new one.

## Local development

Use Node 24 and Xcode/Swift 6. No Cloudflare account, remote D1 database, Apple
credentials, Docker or external server is needed for automated tests.
See the [development guide](development.md) for a complete local walkthrough,
separate staging/production databases, secrets and native app build controls.

```sh
cd worker
npm ci
npm run check
npm test
npm run migrate:local
npm run dev
```

Tests use the real Workers runtime and D1 bindings, with mocked Apple/Access HTTP
responses. `worker/test/native-fixtures.json` is generated by the Swift VM:

```sh
swift run HerbertJudgeFixtures > worker/test/native-fixtures.json
```

It covers current original solutions, alternative traversals, incomplete programs
and runaway recursion; the HOJ language fixtures also run against the Worker VM.
The executable/tool and reference solutions are never linked into an app.

## Production setup

This PR does not create cloud resources or enroll/configure an Apple account.

1. First validate the separate staging setup in the development guide. Create
   production D1 with `npx wrangler d1 create herbert-leaderboard-production`.
   Put its ID in **`env.production.d1_databases[0].database_id`** in
   `worker/wrangler.jsonc`; keep staging and the local root binding separate.
2. Enable Sign in with Apple for `info.hugogu.Herbert` in Apple Developer and
   create an associated private key. Register `https://your-api-domain/v1/auth/apple/notifications`
   as the primary App ID's server-to-server notification endpoint. Configure `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`
   and `APPLE_KEY_ID` in `env.production.vars`. Register the App ID for the target
   you actually distribute; native login does not use a website Services ID.
3. Set Worker secrets using `npx wrangler secret put NAME --env production`: `APPLE_PRIVATE_KEY`
   (the P8 PEM), `SESSION_SECRET` (at least 32 random bytes as text) and
   `TOKEN_ENCRYPTION_KEY` (base64 of exactly 32 random bytes). Never commit these.
4. Apply migrations using `npm run migrate:production`, then `npm run deploy:production`.
   Assign an HTTPS API domain. All API responses use `Cache-Control: no-store`;
   do not add a CDN rule that overrides this. There is no browser CORS API:
   the native app calls HTTPS directly.
5. In ignored `Config/Local.xcconfig`, configure the signing team and
   `HERBERT_CLOUD_PRODUCTION_URL = https:/$()/api.example.com`. Xcode uses `$()` to avoid
   interpreting `//` as a comment. An unset URL leaves online features disabled.
   Build/archive **HerbertAppStore** with **Release** and its Apple login
   entitlement. Debug uses the separate staging URL and staging App ID.
6. Update the public privacy policy and App Store privacy declarations to cover
   the account ID, uploaded H programs and scores. The App Store target includes
   a matching privacy manifest. Configure retention and an operator contact.
7. Test Apple sign-in, relaunch/refresh, logout, deletion/re-registration, uploads
   and Mainland network reachability on signed devices before release.

The existing ad-hoc GitHub DMG keeps its local/AI features and no Apple login
entitlement. Native Sign in with Apple is not supported for Developer ID Mac
apps; a future signed DMG login would need a separately configured web flow.

**Budget:** synchronous verification must fit Worker CPU limits. Stress fixtures
can take longer than the free plan's 10 ms; benchmark on the deployed plan before
enabling submissions. Use a paid Worker CPU allowance or a queue-based judge if
needed; never lower validation quality or trust a client score to fit the quota.
The sample explicitly caps CPU at 1,000 ms per invocation (`limits.cpu_ms`) as a backstop and requires a paid Worker plan for this override.
An environment-specific `IP_LIMITER` binding enforces 120 requests per minute per IP hash without D1 writes.
Its namespace ID must be unique within your Cloudflare account; the sample uses distinct local/staging/production IDs.
The edge limiter is approximate and local to a Cloudflare location, not an exact global quota.
D1 retains strict per-user upload/profile and login quotas. Public reads remain uncached.
Maintenance runs every five minutes. These limits are an initial policy, not DDoS protection.

## Account lifecycle

Logout revokes the current Herbert session. Account deletion atomically removes the Apple subject/credential,
revokes all sessions, blanks uploaded programs, hides scores and queues encrypted Apple revocation in
`apple_revocations` (migration 0003). Local erasure succeeds even when Apple credentials or networking fail.
The outbox has no user/profile linkage; its ciphertext is retained only while retryable. A scheduled drain
claims at most ten due jobs with leases, uses exponential backoff (60 seconds to six hours) and makes at
most eight external attempts. Success, exhausted retries or an undecryptable grant clears the ciphertext.
Rotated-away keys produce an `unrevocable` status, not a failed deletion. Operators must investigate
terminal `apple_revocation_failed` logs; terminal outbox metadata expires after 30 days. Keep the old
encryption key available until pending jobs drain when planning a key rotation.

Retained user/submission records are tombstones with internal IDs and numerical results, not recoverable
profiles. Local exercises/backups remain untouched. Choose and publish retention for tombstones/audits.
Never log bodies, bearer tokens, Apple credentials or source programs. Unexpected failures have a safe
`internal_error` code and reference logged server-side. Apple failures return generic localized client
messages plus code/reference; curated configuration hints remain in operator logs.

Signed Apple server notifications are verified against Apple's keys, issuer and
this App ID. `consent-revoked` invalidates existing sessions and encrypted Apple
credentials; `account-deleted` also removes uploaded sources and hides standings.
Replay markers make repeated deliveries idempotent; event timestamps protect
later authorizations. No notification JWT or email preference is persisted.

## Independent administration project

Application schema is owned by numbered D1 migrations in `worker/migrations/`;
all names are snake_case. A future admin project should call the **versioned admin
API**, not write business tables directly. That preserves judge provenance,
moderation rules, audit records and compatibility while keeping its UI separate.
Read-only D1 exports can be used for analytics; deployments/migrations use a
separate least-privilege Cloudflare account token on the operator side.

Protect the admin domain/path with Cloudflare Access and set `ADMIN_ISSUER`
(`https://your-team.cloudflareaccess.com`), `ADMIN_AUDIENCE` (Access application's
AUD) and `ADMIN_EMAILS` (comma-separated allowlist). They are empty/disabled by
default. The Worker independently verifies the signed Access JWT and allowlisted
email. Unsigned email headers and a player's JWT never grant administrative
access. Do not forward private keys or Access service-token secrets to a browser.
A separate admin backend can relay the authenticated operator's Access assertion;
it must use the same intended audience, and be protected itself.

- `GET /admin/v1/users`: latest 100 profiles, excluding credentials/Apple subjects.
- `GET /admin/v1/submissions`: latest 100 non-deleted users' submissions, including
  programs and judge results for inspection.
- `PATCH /admin/v1/users/{user_id}`: `{ "status": "blocked" | "active", "reason": "…" }`.
  Blocking also revokes sessions. Alternatively `{ "reset_name": true, "reason": "…" }` replaces an abusive nickname with the generated Learner alias without blocking or changing scores. Choose one action per call. Deleted accounts cannot be restored.
- `PATCH /admin/v1/submissions/{submission_id}`: `{ "hidden": true | false, "reason": "…" }`.
  Hiding removes the attempt from ranking; an earlier valid attempt can still count.

Changes and their actor/reason are recorded atomically in `admin_audit`; no hard
user/submission deletion API exists. There is deliberately no API for assigning
arbitrary scores or uploading alternative boards. Add pagination, roles and new
operations under this contract as the separate admin product needs them.

## Public API v1

JSON request/response fields use snake_case. Authenticated calls use
`Authorization: Bearer <Herbert access token>`.

| Method/path                                          | Authentication     | Purpose                                                                                                         |
| ---------------------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `GET /v1/problems`                                   | Public             | Current original IDs, versions, limits and rules version                                                        |
| `GET /v1/problems/bests`                             | Public             | Minimum accepted size per current puzzle, across active visible submissions; rules and puzzle versions included |
| `GET /v1/leaderboard?limit=50`                       | Public             | Top 1–100 current aggregate scores                                                                              |
| `GET /v1/problems/{problem_id}/leaderboard?limit=50` | Public             | Top 1–100 best per-user attempts for a current original puzzle                                                  |
| `POST /v1/auth/challenge`                            | Public, throttled  | `{ challenge_id, nonce }`, valid for 5 minutes                                                                  |
| `POST /v1/auth/apple`                                | Apple proof        | `{ challenge_id, nonce, identity_token, authorization_code }` → session and user                                |
| `POST /v1/auth/apple/notifications`                  | Signed Apple event | Revoke sessions or remove a deleted Apple account                                                               |
| `POST /v1/auth/refresh`                              | Refresh token      | `{ refresh_token }` → rotated session credentials                                                               |
| `GET /v1/me`                                         | Session            | Current profile                                                                                                 |
| `PATCH /v1/me`                                       | Session            | Save the current user's public `display_name`                                                                   |
| `POST /v1/auth/logout`                               | Session            | Revoke current session                                                                                          |
| `DELETE /v1/me`                                      | Session            | Revoke Apple authorization and delete cloud account                                                             |
| `GET /v1/me/submissions`                             | Session            | Last 100 own judge results                                                                                      |
| `POST /v1/submissions`                               | Session, throttled | `{ request_id, problem_id, puzzle_version, source }` → trusted judge result                                     |

Errors return `{ "error": "…", "code": "…", "reference": "…" }` (code/reference are optional); 401 means reauthenticate, 403 means forbidden,
409 means stale puzzle/reused request ID, 413 means body too large, and 429 includes
`Retry-After`. Reuse the same submission request ID only with identical content.

Official references: [Apple identity verification](https://developer.apple.com/documentation/signinwithapple/verifying-a-user),
[account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/),
[signed account notifications](https://developer.apple.com/documentation/signinwithapple/processing-changes-for-sign-in-with-apple-accounts),
[Developer ID limitation](https://developer.apple.com/forums/thread/793244),
[D1 migrations](https://developers.cloudflare.com/d1/reference/migrations/),
[Workers limits](https://developers.cloudflare.com/workers/platform/limits/).

## Public nickname safety

New nicknames pass the pinned MIT `obscenity` English filter and a small Chinese/Japanese abuse baseline.
This screening is imperfect and is complemented by reporting and human moderation. Each other player's
ranking row has **Report nickname** (opens an email draft to the published support contact) and **Hide player
on this device**. Hidden players can be restored in the same ranking page; preferences stay on that device,
scoped to the service URL. Reports are sent only when the user chooses to send the draft. Operators review
reports promptly and can reset names, hide submissions or block accounts through the audited admin API.
Publish a monitored contact and moderation process before release; a text filter alone does not guarantee safety.

[Cloudflare Rate Limiting binding](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)
describes namespace isolation, local counters and their approximate enforcement.
