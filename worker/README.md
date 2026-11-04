# Herbert verified leaderboard

Cloudflare Workers API and D1 migrations for the optional native App Store
leaderboard. [Setup, authentication, API contract and independent administration](../docs/cloud-leaderboards.md).

Use Node 24. Local testing needs no Cloudflare account, remote D1 database or
Apple credentials. See the [development guide](../docs/development.md) for
staging/production setup and native app environment selection.

Run these commands inside `worker/`, not at the repository root:

```sh
npm ci
npm run check
npm test
npm run migrate:local
npm run dev
```

The default listener is `localhost:8787`. For LAN HTTP connectivity tests, stop
the server and use `npm run dev -- --ip 0.0.0.0`; access it using your Mac's LAN
IP, not the phone's `127.0.0.1`. Native App integration requires HTTPS, even when
an HTTP URL is visible in Xcode Build Settings. See the development guide's
[phone access](../docs/development.md#access-the-local-api-from-a-phone-or-another-computer)
and [HTTPS tunnel setup](../docs/development.md#local-secrets-and-real-apple-login).

Production deployment needs your own D1 ID, Apple configuration and Worker secrets.
Select `npm run migrate:staging` / `deploy:staging` or
`npm run migrate:production` / `deploy:production` explicitly. Each environment
has its own Worker, D1 database, token issuer and secrets in `wrangler.jsonc`.
No credentials are included. The local learning build does not link this service.
