# Herbert verified leaderboard

Cloudflare Workers API and D1 migrations for the optional native App Store
leaderboard. [Setup, authentication, API contract and independent administration](../docs/cloud-leaderboards.md).

```sh
npm ci
npm run check
npm test
npm run migrate:local
npm run dev
```

Production deployment needs your own D1 ID, Apple configuration and Worker secrets.
No credentials are included. The local learning build does not link this service.
