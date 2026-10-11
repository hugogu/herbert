# Herbert verified leaderboard

Cloudflare Workers API and D1 migrations for the optional native App Store
leaderboard. [Setup, authentication, API contract and independent administration](../docs/cloud-leaderboards.md).

Use Node 24. Local testing needs no Cloudflare account, remote D1 database or
Apple credentials. See the [development guide](../docs/development.md) for
staging/production setup and native app environment selection.

```sh
npm ci
npm run check
npm test
npm run migrate:local
npm run dev
```

Production deployment needs your own D1 ID, Apple configuration and Worker secrets.
Select `npm run migrate:staging` / `deploy:staging` or
`npm run migrate:production` / `deploy:production` explicitly. Each environment
has its own Worker, D1 database, token issuer and secrets in `wrangler.jsonc`.
No credentials are included. The local learning build does not link this service.
