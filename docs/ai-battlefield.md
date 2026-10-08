# AI Battlefield

Available in both editions from **0.3.0**, with two separate navigation tabs:
**AI Providers** and **AI Battlefield**. The ordinary puzzle game remains fully offline.

## Connect models

1. In **AI Providers**, add OpenRouter, SiliconFlow, or an OpenAI compatible provider.
2. Enter its HTTPS base URL and your own API key. Saving automatically requests
   `GET /models`; SiliconFlow adds `sub_type=chat` to discover chat models.
3. Select any default entrants. Configure each model's output cap, optional temperature
   and top P, and supported advanced JSON parameters. Blank sampling values use provider defaults.
4. Use **Refresh models** after provider permissions or model availability change.

The base URL ends at the API version, for example `https://openrouter.ai/api/v1` or
`https://api.siliconflow.cn/v1`; do not append `/models` or `/chat/completions`.
The standard discovery endpoint is plural **`/models`**, not `/model`.
Custom endpoints must support OpenAI-style chat completions. Choose `max_tokens` or
`max_completion_tokens` according to that provider. Authentication uses the Bearer header.
Redirects are rejected; enter the final URL directly. HTTP endpoints are not accepted.

Advanced parameters allow `seed`, `top_k`, `min_p`, `frequency_penalty`,
`presence_penalty`, `reasoning_effort`, `reasoning`, `enable_thinking`, and `thinking_budget`.
Provider support varies; invalid combinations can return an API error. Model, message,
stream and token-cap fields cannot be overridden by advanced JSON.

Protocol references: [OpenRouter models](https://openrouter.ai/docs/api/api-reference/models/list-all-models-and-their-properties),
[chat](https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request),
[usage](https://openrouter.ai/docs/cookbook/administration/usage-accounting),
[SiliconFlow models](https://api-docs.siliconflow.cn/docs/api/models-get),
[chat](https://api-docs.siliconflow.cn/docs/api/chat-completions-post).

## Run a match

**New match** starts with your default entrants and all **50 original puzzles**, L01–L50.
Choose up to 32 provider/model pairs and a subset of puzzles. The open-source edition
also permits community puzzles; the App Store edition exposes only its 50 originals.
Models run concurrently, with one request at a time per model. Each model works through
the same puzzles in catalog order, using the exact same English rules and board prompt.
Optional additional instructions are identical for every entrant.

| Mode | End condition |
| --- | --- |
| Time limited | A monotonic deadline cancels all requests and local judging. Default: 600 seconds. |
| Token limited | Input + output tokens across all attempts reach the budget, or the next prompt cannot fit. Default: 100,000, shared across the match. An equal independent budget per model is also available. |
| Best Effort | No match time or aggregate token limit. Finishes after all puzzles have exhausted their attempts or been solved. |

Every mode can finish naturally or be stopped by the user. Individual HTTP requests
have a 600-second timeout; model discovery has a 30-second timeout. Authentication,
quota, transport and protocol failures stop the affected entrant and retain its results;
other entrants continue. There is no automatic paid network retry after such a failure.
On iPhone/iPad, moving the app to the background ends the match and saves its results.
On Mac, switching to another app does not stop it. A force quit or crash is recovered as
**interrupted** from the most recent checkpoint; an interrupted match is reviewed, not resumed.

## Judge and rank

The platform extracts one H program and runs it through the **same HerbertCore parser,
byte counter, VM and board rules used for human play**. Programs that exceed the puzzle's
byte limit, fail to compile, hit execution limits, or leave targets unlit earn no points.
H code cannot invoke tools, access the network or read files.

- **100 points** per solved puzzle; **0** otherwise. This is a Battlefield scoring rule,
  separate from the original site's historical scoring system.
- Rank by total points, then fewer total bytes in accepted programs, then earlier
  completion time. Equal remaining ties use a stable entrant identifier.
- Default **3 attempts per puzzle**, configurable from 1 to 10. A rejected answer receives
  native feedback, byte usage, execution state and remaining attempts. The next attempt
  includes this puzzle's conversation; each new puzzle starts a fresh conversation.
- Completion stops as soon as every target is lit, including before trailing code.
  Wall collisions continue execution; traps clear lit targets. Original runtime bounds apply.

The dashboard updates ranks, input/output/confirmed token counts, cache rates and each
puzzle's status during the match. Select a status to inspect all attempts, programs,
responses, judging feedback and model settings. Histories retain puzzle snapshots and
the full shared prompt, so later catalog or settings changes do not change old results.
Remote model versions and provider routing can still change; snapshots do not make a
third-party model deterministic.

## Understand token accounting

Providers often return exact usage only at the end of a stream. During generation,
Herbert estimates tokens from UTF-8 bytes and includes prompt/message overhead; **≈**
means estimated or partial usage. Final reported usage replaces estimates rather than
being added a second time. Output includes reasoning tokens; they are not double-counted.
Input cache rate is cached input / total input and appears only when **every attempt**
reports complete cache usage. Missing data displays **Unavailable**, distinct from 0%.

Shared budgets reserve output capacity across concurrent requests and cap each request's
output. Estimates are reconciled with provider usage. Stopping cancels the underlying
URLSession tasks and prevents late answers from receiving points. **A token budget is
not a billing guarantee**: tokenizers differ, an aborted request may lack final usage,
and a remote provider can continue processing after local cancellation. Check provider
usage and use provider-side spending limits for a hard financial cap.

## Local data and sharing

`HerbertBattlefield` is a UI-independent Swift package. `BattlefieldRepository` separates
storage from the engine. `LocalBattlefieldRepository` stores versioned JSON below the app's
Application Support directory: `Herbert/Battlefield/providers.json`,
`history/index.json`, and one `history/<match UUID>.json` per match. Writes are atomic and
serialized; initial/final snapshots save immediately, live checkpoints at most twice per
second. A result written before its index is recovered on the next read. Corrupt or
unknown-version data is preserved and reported instead of silently overwritten.

API keys use the system **Keychain**, with device-only accessibility and no Keychain sync.
Keys are runtime-only values; Codable settings/results and PNG images never include them.
Removing a provider removes its key and configuration, while keeping past matches.
Progress JSON backups cover human game progress, not AI credentials or match history.

Completed matches offer **Share result image**: a locally rendered 1080-pixel-wide PNG
with every entrant's rank, score, solved count, accepted bytes, token usage and cache rate.
It includes model and provider display names; review those before sharing. Images omit
API keys, endpoint URLs, raw responses and custom prompts. The system share sheet sends
the image only to the destination you choose. No public leaderboard or upload service exists.

See [privacy details](../PRIVACY.md). Future Cloudflare sync must use an authenticated
Worker and explicit consent; no client D1 credentials or cloud sync are included.

## Verification

Unit tests exercise native judging, bounded retries, parallelism, deadlines, shared and
per-model budgets, cancellation, persistence and corrupt data. HTTP integration tests use
URLProtocol fixtures to exercise authenticated discovery, actual SSE byte parsing,
JSON fallback, usage reconciliation and cancellation after response headers. Native UI
tests use an isolated, deterministic client and in-memory keys; their screenshots are
real app captures of test data, **not claims about any commercial model's ability**.
Real OpenRouter/SiliconFlow calls require your own API key and device verification.
