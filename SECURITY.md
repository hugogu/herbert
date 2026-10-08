# Security policy

## Supported versions

Security fixes currently target the latest `main` branch and the latest preview release.
Older preview versions do not receive separate backports.

## Report privately

Please use [GitHub's private vulnerability reporting form](https://github.com/hugogu/herbert/security/advisories/new).
If it is unavailable, email hugogu@outlook.com. Do not disclose an exploitable issue in a
public issue before a fix or coordinated disclosure.

Include the affected version, platform, a minimal reproduction, impact, and a sample
H program or backup file if relevant. Remove personal progress and sensitive information.
There is no paid bug bounty or guaranteed response-time commitment.

## Relevant boundaries

H programs run in a bounded custom interpreter. Backup files are untrusted input: imports
validate their schema, size, IDs, and claimed solutions before merging. Parser recursion,
expansion budgets, save corruption, and malicious backup handling are useful review areas.

The current app has no account or cloud service. Never place Cloudflare credentials in
clients; any future D1 access must go through an authenticated Worker.

AI Battlefield accepts user-configured HTTPS providers. Keys belong only in Keychain
and runtime Authorization headers, never in Codable settings/history, logs, screenshots
or shared images. Redirects, oversized responses, unbounded streams, late callbacks after
cancellation, budget reservations and unexpected provider JSON are relevant review areas.
Match history contains user prompts and full model responses; redact them when reporting.
