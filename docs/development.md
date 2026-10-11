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

Expect HTTP 200, `Cache-Control: no-store`, 30 original problems, an initially empty
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

### Local secrets and real Apple login

Public reads and login challenges work without secrets. For a manual real-login
test, copy [`worker/.dev.vars.example`](../worker/.dev.vars.example) to
`worker/.dev.vars` if it does not already exist, and fill in **staging** Apple
credentials. Generate a fresh `SESSION_SECRET` with `openssl rand -hex 32` and
`TOKEN_ENCRYPTION_KEY` with `openssl rand -base64 32`. Put the P8 PEM in a quoted
`APPLE_PRIVATE_KEY` value with escaped `\n` newlines. Protect the file with
`chmod 600 .dev.vars`; it is ignored by Git. Never use production secrets locally.
Local files are not uploaded by `wrangler deploy`.

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
