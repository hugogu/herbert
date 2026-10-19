# Development guide: local, staging and production

**Local tests do not require a Cloudflare account or a remote D1 database.**
Wrangler runs the Worker and D1 on your computer. Create a separate staging D1
database only when testing the deployed API or the complete signed-device Apple
login/upload flow. Production must use a different database.

## Environment controls

| Environment | Worker selection | Database | Native app selection |
| --- | --- | --- | --- |
| Automated tests | `npm test` | Isolated test D1; migrations applied by tests | `swift test` uses mocked HTTP |
| Manual local API | `npm run dev` | Local SQLite under `worker/.wrangler/state/` | Optional trusted HTTPS tunnel to local Worker |
| Staging | `--env staging` | `herbert-leaderboard-staging` | `HerbertAppStore`, **Debug**, `HERBERT_CLOUD_STAGING_URL` |
| Production | `--env production` | `herbert-leaderboard-production` | `HerbertAppStore`, **Release / Archive**, `HERBERT_CLOUD_PRODUCTION_URL` |

Worker names, D1 bindings, Apple audiences and token issuers are in
[`worker/wrangler.jsonc`](../worker/wrangler.jsonc). Each named environment has its
own bindings and variables; Wrangler does not inherit these from the root.
The root configuration is local-only, with a dummy database ID. Local npm scripts
explicitly select the root and local storage, even if `CLOUDFLARE_ENV` is set.
There is no ambiguous `npm run deploy` or `migrate:remote` script: choose the
environment explicitly. Do not add `remote: true` to a development D1 binding.

## Run automated checks first

Use **Node 24** for the Worker and Xcode 16+/Swift 6 for the native app.
From the repository root:

The Node project and its committed lockfile are in **`worker/`**, not the
repository root. Run the npm commands after `cd worker`. If `npm ci` reports
that no lockfile exists, check `pwd`; do not generate a new root lockfile with
`npm install`. Alternatively, run `npm --prefix worker ci` from the repository root.

```sh
scripts/check.sh
cd worker
npm ci
npm run check
npm test
```

Worker tests run the real Workers runtime and D1 migrations, with local fixtures
for Apple/Cloudflare Access responses. They verify authentication, authorization,
judge parity, account lifecycle and environment separation without credentials
or a deployed Worker. A separate integration test starts the actual Wrangler
entrypoint, migrates a temporary local database and checks the HTTP API. Test
D1 state is separate from the manual development
database and your remote databases. No `wrangler login`, `d1 create` or manual
migration step is needed for `npm test`.

Native checks include `HerbertCloud` HTTP integration tests; real Apple login still
needs a signed device. Mac UI tests require an unlocked, interactive desktop;
see [CONTRIBUTING](../CONTRIBUTING.md#before-opening-a-pull-request).
CI also checks that the production origin is present in the built Mac/iOS
Info.plist; custom configuration must survive packaging to reach the native client.

## Run the API and database locally

From `worker/`, after `npm ci`:

```sh
npm run migrate:local
npm run dev
```

In another terminal:

```sh
curl -i http://127.0.0.1:8787/v1/problems
curl -i http://127.0.0.1:8787/v1/leaderboard
curl -i -X POST http://127.0.0.1:8787/v1/auth/challenge
```

Expect HTTP 200, `Cache-Control: no-store`, 50 original problems, an initially empty
leaderboard and a fresh login challenge. Inspect the local database without
changing it:

```sh
npx wrangler d1 execute DB --local --env= --persist-to .wrangler/state \
  --command 'SELECT COUNT(*) AS user_count FROM users'
```

Both local npm scripts use `.wrangler/state`, so migrations and the dev server
share persistent data. Restarting does not reset it. To try a fresh database,
pass a new directory to **both** commands, rather than dropping tables:

```sh
npx wrangler d1 migrations apply DB --local --env= --persist-to .wrangler/scratch
npx wrangler dev --local --env= --persist-to .wrangler/scratch
```

The checked-in dummy database IDs are sufficient locally. These commands neither
create nor access a Cloudflare database. Schema changes belong in new numbered
files under `worker/migrations/`; apply them with the matching migration script.

### Access the local API from a phone or another computer

`npm run dev` uses Wrangler's default `localhost` listener. A successful request
to `127.0.0.1:8787` on your Mac does not mean the server accepts LAN connections.
Stop the existing dev server with Ctrl-C, then run this from `worker/`:

```sh
npm run dev -- --ip 0.0.0.0
```

This keeps the same local database and environment, but listens on all network
interfaces. `0.0.0.0` is a listening address, not an address to enter on a phone.
Use your Mac's current LAN IP instead, for example:

```sh
curl -i http://192.168.1.42:8787/v1/problems
```

Replace the example IP with your Mac's address from System Settings → Network.
Test from the Mac first, then open the same URL in Safari on your phone. Both
devices must have a network route to each other (normally the same Wi-Fi).
If loopback works but LAN access still fails, check macOS Firewall, Wi-Fi client
isolation, and VPN routing. A phone's `127.0.0.1` refers to the phone itself.
Only expose the dev server on a trusted network; it serves your local test data.

**This HTTP check verifies connectivity, not native App login.** The native
client requires HTTPS; follow the tunnel instructions below or use staging.
See [Wrangler's `--ip` option](https://developers.cloudflare.com/workers/wrangler/commands/workers/).

### Local secrets and real Apple login

Public reads and login challenges work without secrets. For a manual real-login
test, copy [`worker/.dev.vars.example`](../worker/.dev.vars.example) to
`worker/.dev.vars` if it does not already exist, and fill in **staging** Apple
credentials. Generate a fresh `SESSION_SECRET` with `openssl rand -hex 32` and
`TOKEN_ENCRYPTION_KEY` with `openssl rand -base64 32`. Put the P8 PEM in a quoted
`APPLE_PRIVATE_KEY` value with escaped `\n` newlines. Protect the file with
`chmod 600 .dev.vars`; it is ignored by Git. Never use production secrets locally.
Local files are not uploaded by `wrangler deploy`.

#### What goes into `APPLE_PRIVATE_KEY`?

The downloaded `.p8` file **is the private key**. The Worker needs its complete
PEM text, including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`.
Do not put the filename, path, a certificate, or a newly generated random secret
in this variable. Use a **Sign in with Apple** key associated with the staging
App ID (or its configured primary App ID), not an App Store Connect API key.
See [Apple's key setup](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key/).

In `worker/.dev.vars`, write the PEM as a single double-quoted line, replacing
each actual line break with `\n` (one backslash followed by `n`):

```dotenv
APPLE_TEAM_ID="YOUR_TEAM_ID"
APPLE_KEY_ID="YOUR_KEY_ID"
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_REAL_P8_BASE64_LINES\n-----END PRIVATE KEY-----\n"
```

Replace the placeholder with **every base64 line from your own P8**; do not copy
this placeholder literally. `APPLE_KEY_ID` is the identifier of this key in Apple
Developer; `APPLE_TEAM_ID` is your developer team's identifier. Neither is the
key's contents. `APPLE_CLIENT_ID` is the **native app Bundle ID**, configured in
`wrangler.jsonc` (`info.hugogu.Herbert.Staging` for Debug), not the Team ID, Key ID,
or tunnel hostname. `.dev.vars` can override that setting, so check for an old
override if the audience mismatches.

Restart `npm run dev` after changing credentials, then start a fresh Apple login;
authorization codes are short-lived and single-use. Keep the original P8 safely:
Apple only allows downloading it once. Never put it in `Local.xcconfig`, the app,
`wrangler.jsonc`, Git, a screenshot, or a diagnostic message. Local secrets use
[Wrangler's `.dev.vars` support](https://developers.cloudflare.com/workers/configuration/secrets/);
remote staging secrets must be set separately with `wrangler secret put`.

#### Diagnose an Apple login failure

The app displays a diagnostic code and reference UUID. Find the same reference
in the local Wrangler terminal (or deployed Worker logs). Logs contain only an
allowlisted code and reference, never the token, authorization code, private key,
Apple subject, or original exception. Do not paste those secrets when reporting
an error. A successful `/v1/problems` request verifies our API, not its ability to
reach Apple's authentication services.

| Code | Meaning / action |
| --- | --- |
| `apple_audience_mismatch` (401) | Match the running app Bundle ID to the Worker's `APPLE_CLIENT_ID`. |
| `apple_token_expired`, `apple_nonce_mismatch`, `apple_code_invalid` (401) | Start a new login; check the system clock if expiration persists. |
| `apple_token_invalid`, `apple_claim_invalid`, `apple_signature_invalid`, `apple_subject_missing` (401) | Identity proof was rejected; retry a fresh native login and investigate if persistent. |
| `apple_keys_unavailable` (503) | Worker could not load Apple's signing keys; check DNS, proxy and access to `https://appleid.apple.com/auth/keys`. A successful host curl does not guarantee Wrangler has the same network route. |
| `apple_client_id_missing`, `apple_credentials_missing` (503) | Fill in the indicated Worker configuration. |
| `apple_private_key_invalid` (503) | Supply the full Sign in with Apple P8 PEM, including both header/footer lines. |
| `apple_client_invalid` (503) | Apple rejected the developer credentials; verify Team ID, Key ID, client ID, key association/revocation, and system clock. |
| `apple_service_unavailable`, `apple_authorization_failed` (503) | Apple authorization service could not complete the request; check connectivity and retry. |

A failed login consumes its challenge. Retry using the app's sign-in action;
replaying a captured login request will produce `Login challenge expired`.

There is no development authentication bypass: a challenge is not a session and
submissions still require a verified Apple login. Automated tests inject their
own test keys and mocked proofs; `npm run dev` does not enable those mocks.

The native client requires an **HTTPS origin** without a path, query or fragment.
`http://127.0.0.1:8787` is for curl/browser API testing. For full app integration,
use staging HTTPS (recommended), or expose the local Worker through a trusted
HTTPS tunnel and set `HERBERT_CLOUD_STAGING_URL` to that origin. A tunnel still
uses your local D1; it does not require a remote database. A phone's `localhost`
refers to the phone, not your Mac. Do not bypass certificate validation or relax
App Transport Security; Wrangler's self-signed local HTTPS alone is insufficient.

For a concrete HTTPS tunnel setup, install
[cloudflared](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/),
leave `npm run dev` running, and start a second terminal:

```sh
cloudflared tunnel --url http://127.0.0.1:8787
```

Cloudflared runs on your Mac, so this setup works with the default loopback
listener; `--ip 0.0.0.0` is unnecessary for the tunnel. It prints a temporary
`https://...trycloudflare.com` URL. Check that URL's `/v1/problems` endpoint on
your phone, then put its origin in ignored `Config/Local.xcconfig`:

```xcconfig
HERBERT_CLOUD_STAGING_URL = https:/$()/YOUR-TUNNEL.trycloudflare.com
```

Replace the hostname with the actual tunnel hostname, without `/v1/problems`.
Rebuild and run the **HerbertAppStore** scheme in **Debug**, then open
**My → Progress → Global leaderboard**. An HTTP URL can appear correctly in Xcode's
Build Settings while still being rejected by the native client. A tunnel restart
can change the hostname, requiring another configuration update and rebuild.
Keep both processes running. The tunnel makes the local API publicly reachable;
use test data and secrets. It still uses local D1, and authenticated submissions
still require the real Apple login configuration described above.


## Create a remote staging environment

Only this section needs a Cloudflare account and Apple Developer configuration.
From `worker/`:

1. Authenticate with `npx wrangler login` (or an operator-side Cloudflare API token).
2. Run `npx wrangler d1 create herbert-leaderboard-staging`. If prompted to update
   configuration automatically, decline and place the returned `database_id` in
   **`env.staging.d1_databases[0]`** in `wrangler.jsonc`. Leave the root local ID
   and `env.production` untouched. Database IDs are identifiers, not secrets.
3. Register **`info.hugogu.Herbert.Staging`** as a separate App ID in Apple
   Developer, enable Sign in with Apple, and configure its signing profiles/key.
   Fill `env.staging.vars.APPLE_TEAM_ID` and `APPLE_KEY_ID`; `APPLE_CLIENT_ID`
   must match the staging app's bundle ID. Keep staging's Apple authorization
   group separate from production so deletion/revocation tests stay isolated.
4. Set fresh, staging-only Worker secrets. The commands read values interactively:

   ```sh
   npx wrangler secret put SESSION_SECRET --env staging
   npx wrangler secret put TOKEN_ENCRYPTION_KEY --env staging
   npx wrangler secret put APPLE_PRIVATE_KEY --env staging
   ```

   Use the same key formats described above. `secret put` changes the selected
   remote Worker immediately (and can create its initial draft); it does not
   read secrets from `.dev.vars`.
5. Apply migrations and deploy:

   ```sh
   npm run migrate:staging
   npm run deploy:staging
   ```

6. Use the resulting HTTPS origin (or your own staging API domain). Register
   `{origin}/v1/auth/apple/notifications` as the staging primary App ID's
   server-to-server notification URL. Production needs its own callback.
7. Configure the native Debug endpoint below, then test sign-in, saved-solution
   upload, server-verified scores, relaunch/refresh, logout, deletion and
   re-registration on your signed iPhone/iPad/Mac. An unsigned build cannot
   validate Apple sign-in. Check reachability on the networks you will support.

For production, repeat with a **new** `herbert-leaderboard-production` database,
`env.production`, `--env production`, and the production Apple App ID
`info.hugogu.Herbert`. Use distinct secrets, run `npm run migrate:production`, then
`npm run deploy:production`. Never point both environments at the same D1 ID or
reuse session/encryption secrets. There is no automatic deployment in CI.
Review [production/privacy requirements](cloud-leaderboards.md#production-setup)
and Worker CPU limits before opening production submissions.

## Select the native app environment

Merge these settings into the ignored **`Config/Local.xcconfig`**. If the file is
absent, start from [`Config/Local.xcconfig.example`](../Config/Local.xcconfig.example).
Keep your existing signing settings:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
HERBERT_CLOUD_STAGING_URL = https:/$()/staging-api.example.com
HERBERT_CLOUD_PRODUCTION_URL = https:/$()/api.example.com
```

Xcode needs `$()` to prevent `//` from being parsed as a comment. These are origins,
without `/v1` or other paths. An empty/invalid URL leaves cloud features disabled.
Remove the previous single `HERBERT_CLOUD_URL` entry if you configured it earlier;
replace it with the two entries above.

The generated `HerbertAppStore` target maps **Debug** to the staging URL and
bundle ID `info.hugogu.Herbert.Staging` (display name **Herbert Staging**), and
**Release** to the production URL and bundle ID `info.hugogu.Herbert`.
In **Product → Scheme → Edit Scheme**, Run/Test default to Debug; Archive defaults
to Release. Switching the build configuration switches the endpoint. To test a
production-optimized build against staging, explicitly pass
`HERBERT_CLOUD_URL=https://staging-api.example.com` **and**
`PRODUCT_BUNDLE_IDENTIFIER=info.hugogu.Herbert.Staging` as command-line build
settings, with an appropriate staging signing profile. Build settings are
compiled into the app; there is no runtime production switch for players.

Staging and production apps can coexist and have separate local containers.
Cloud sessions are also scoped to their API origin in Keychain. `Herbert` remains
the offline/community + AI edition, and `HerbertLearning` excludes cloud and AI;
neither scheme uses these endpoints. The default community app and production
App Store app share a bundle ID; export progress before replacing one with the
other. Regenerating the Xcode project preserves `Local.xcconfig`.

The current schema and versioned admin API are shared across environments, but a
future administration project must choose the matching API/Cloudflare Access
audience. Player JWTs and staging admin assertions cannot grant production admin
access. Do not put an Apple P8 key, D1/Cloudflare API token or admin service-token
secret in an app build setting.

References: [Wrangler environments](https://developers.cloudflare.com/workers/wrangler/environments/),
[local D1](https://developers.cloudflare.com/d1/best-practices/local-development/),
[local and deployed secrets](https://developers.cloudflare.com/workers/configuration/secrets/).
