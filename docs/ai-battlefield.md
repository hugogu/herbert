# AI Battlefield

Available in both editions from **0.3.0**, refined in **0.3.5**. The app has four main
tabs; **AI Battlefield** contains **AI Providers**, **New match**, **Current match** and
**Match history** in its title bar. The ordinary puzzle game remains fully offline.

## Connect models

1. In **AI Battlefield → AI Providers**, add OpenRouter, SiliconFlow, or an OpenAI compatible provider.
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

The default output cap is **65,536 tokens**, including reasoning. **New match → selected
model → sliders → Maximum output tokens** opens the same persistent editor as the
provider’s model list. A **Use 64K output limit** button restores the default. The actual
request uses the lowest of the configured cap, a provider-declared model maximum, and
available token budget. Unknown provider limits cannot be inferred automatically.

Settings schema 2 upgrades legacy 4,096-token presets to 65,536 on load. Other custom
caps remain unchanged; an explicit 4,096 cap saved in schema 2 is preserved. Historical
match parameters and actual requested caps are never rewritten.

On iPhone the four pages use short titles with icons: **Models / New / Live / History**.
On Mac, history opens wide enough for three model columns; history and answer dialogs
can be resized in both dimensions. Reasoning is collapsed independently of final text
and rendered with Markdown headings, emphasis, lists, quotes and fenced code.

Advanced parameters allow `seed`, `top_k`, `min_p`, `frequency_penalty`,
`presence_penalty`, `reasoning_effort`, `reasoning`, `enable_thinking`, `thinking`, and `thinking_budget`.
Provider support varies; invalid combinations can return an API error. Model, message,
stream and token-cap fields cannot be overridden by advanced JSON.

Protocol references: [OpenRouter models](https://openrouter.ai/docs/api/api-reference/models/list-all-models-and-their-properties),
[chat](https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request),
[usage](https://openrouter.ai/docs/cookbook/administration/usage-accounting),
[SiliconFlow models](https://api-docs.siliconflow.cn/docs/api/models-get),
[chat](https://api-docs.siliconflow.cn/docs/api/chat-completions-post).

## Responses, reasoning and HTTP 400 diagnostics

Open an answer in Current match or history. Full response is expanded by default and
updates as the model replies, showing final content, `reasoning_content` / `reasoning`,
and provider error details. Text received before a stream failure is retained. Error bodies
are read up to 64 KiB and redact known credential fields, Bearer values and your API key.
SSE transport metadata no longer consumes a cumulative 4 MiB allowance. Successful
streams bound each event to 16 MiB and decoded answer + reasoning text to 8 MiB; JSON
fallback bodies are bounded to 16 MiB with the same decoded content limit. These are
local memory safeguards, separate from the model’s output token cap. Oversized content
retains text received before the limit. Fenced H programs have a separate 64 KiB parsing
limit; explanatory prose outside the code block does not consume it. History files retain
the existing 64 MiB storage bound and report save failures rather than silently dropping text.
Older 0.3.1 histories cannot recover text that the older client discarded.

A `finish_reason: length` reply with reasoning but no final answer means the model used
its output allowance without returning H. Reasoning counts toward the output cap.
Increase that model's cap or adjust reasoning parameters supported by your provider.
For Kimi, `thinking` is now allowed in advanced JSON; use only options supported by the
specific endpoint/model. A larger allowance consumes more credits and is not a correctness guarantee.

Retries now replay the original reasoning field with a nonempty assistant answer. If
there was no final answer, judge feedback is merged into the last user message instead
of sending an empty assistant turn. Moonshot's [official Kimi SDK](https://moonshotai.github.io/kosong/kosong/chat_provider/kimi.html)
preserves reasoning on assistant turns and documents empty text compatibility errors.
Kimi also documents missing reasoning as an HTTP 400 cause in its [error reference](https://www.kimi.com/code/docs/en/kimi-code/error-reference.html), specifically for assistant tool-call messages.
These were request defects in 0.3.1; the exact cause of a historical HTTP 400 cannot be
confirmed when its body was discarded. New diagnostics expose the provider's message
and parameter details without making an unsupported automatic parameter change.

The shared prompt is **`herbert-h-v4`**: explicit row/column rulers, start/target
coordinates, wall/edge behavior, numeric-call termination, instruction arguments and
post-recursion work. Two complete worked boards include a wall/trap example and a
recursive pinwheel with two numeric parameters and an instruction parameter. They are
separate from the scored catalog; L30's answer is not supplied. Both examples are
replayed through the native judge in tests. Improved instructions do not establish that
a particular commercial model will solve #0002/#0003; no paid model result is claimed.
Compare runs only with matching prompt versions and puzzle IDs. v0.3.3 uses continuous L01–L30 numbers, with ten
introductory lessons followed by twenty advanced challenges, totaling 30 puzzles (maximum 3,000 points).

## Run a match

**New match** starts with your default entrants and all **30 retained original puzzles**.
Choose up to 32 provider/model pairs and a subset of puzzles. The open-source edition
also permits community puzzles; the App Store edition exposes only its 30 originals.
Models run concurrently, with one request at a time per model. Each model works through
the same puzzles in catalog order, using the exact same English rules and board prompt.
Optional additional instructions are identical for every entrant.

| Mode | End condition |
| --- | --- |
| Time limited | A monotonic deadline cancels all requests and local judging. Default: 600 seconds. |
| Token limited | Input + output tokens across all attempts reach the budget, or the next prompt cannot fit. Default: 100,000, shared across the match. An equal independent budget per model is also available. |
| Best Effort | No match time or aggregate token limit. Every entrant can solve or exhaust its attempts on all selected puzzles. The match completes after all entrants finish; an early finisher does not cancel others. |

Every mode can finish naturally or be stopped by the user. Individual HTTP requests
have a 600-second timeout; model discovery has a 30-second timeout. Authentication,
quota, transport and protocol failures stop the affected entrant and retain its results;
other entrants continue. There is no automatic paid network retry after such a failure.
On iPhone/iPad, moving the app to the background ends the match and saves its results.
On Mac, switching to another app does not stop it. A force quit or crash is recovered as
**interrupted** from the most recent checkpoint; an interrupted match is reviewed, not resumed.

## Judge and rank

The platform extracts one H program and runs it through the **same HerbertCore parser,
byte counter, VM and board rules used for human play**. H code cannot invoke tools,
access the network or read files. The 30 original puzzles form **Herbert Benchmark**.

The versioned `coverageAndLengthV1` policy awards:

```text
coverage = final lit targets / total targets
code savings = 1 - H program bytes / puzzle byte limit
attempt score = round(coverage * (80 + 20 * code savings), 2)
puzzle score = highest evaluated attempt score
match points = sum of puzzle scores
benchmark percentage = match points / (100 * selected puzzle count) * 100
```

Compile-invalid, empty and over-limit programs earn zero. Incomplete programs, including
runs stopped by native execution bounds, can earn partial points from their final target
state. Traps clear coverage; visits erased by a trap do not count. Each puzzle is worth
at most 100 points. For example, with 2 targets and a 10-byte limit, a 1-byte program
lighting one target earns **49**; a 3-byte solution lighting both earns **94**; a 4-byte
solution earns **92**. A later failed retry or cancellation preserves an earlier judged
score. Ungraded, interrupted attempts cannot earn points.

- Rank by **score descending**, then **total input + output tokens ascending**, then
  earlier completion time. Count all retries and cached input. Live estimates can change
  the ordering as usage is reconciled. Equal remaining ties use a stable entrant ID.
- Default **3 attempts per puzzle**, configurable from 1 to 10. Rejections receive native
  feedback, current attempt score, byte usage, execution state and remaining attempts.
  Each new puzzle starts a fresh conversation.
- Completion stops immediately when every target is lit, including before trailing code.
  Wall collisions continue execution. Robot steps do not affect scores.
- Old histories without a scoring version retain **100 per solved puzzle**, then accepted
  bytes and completion time. Their scores and standings are not silently recalculated.

The original [HOJ rules](http://herbert.tealang.info/rule.php) rank shorter programs ahead
of longer ones, then earlier submissions; the [public fragments](https://github.com/quolc/hoj)
do not publish a composite points formula. The above formula is our independent benchmark
policy, not a claim of identical original-site scoring.

The progress table itself is the live ranking: model columns move with the standings.
Headers show normalized benchmark percentages, input/output/total tokens and cache rate.
Solved counts sit alongside provider names. Pricing suffixes such as `(free)` are omitted
from model display names; request IDs and saved provider metadata remain intact. Errors appear in
a corner indicator. Two-line cells show status, attempt, points and a program preview.
Select a cell to inspect every submitted answer and its feedback. **Try on board** opens
the actual puzzle snapshot with the answer prefilled; **Back to match** returns to the
results, including from history. Trials can be edited and replayed without modifying
personal drafts, shortest solutions or stored competition results. The table fills the
available window width, with horizontal scrolling for additional models.

For comparable measurements, keep puzzle sets, attempts, output caps and shared prompts
fixed; record sampling/reasoning parameters. Per-model token budgets suit equal resource
comparisons. **Best Effort waits for every entrant** to finish its selected attempts.
A slower entrant can still overtake an early finisher on points or token efficiency.
Provider failures stop only the affected entrant; other entrants continue. Histories retain boards, the full shared prompt, model parameters and scoring
policy. Remote model versions and provider routing can still change; snapshots do not
make a third-party model deterministic.

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
with every entrant's rank, normalized percentage, solved count, accepted bytes, token usage and cache rate.
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

## Select match puzzles

The puzzle sheet keeps search, source filters and selection actions together above the
list. Original lessons are grouped by chapter with board thumbnails and byte budgets.
Switch to **Community** (open-source edition) or **Selected** to review that source or
just the current match set. Search accepts puzzle numbers, localized titles and authors.
**Select visible** adds every filtered result without clearing other choices; **30 original
puzzles** replaces the selection with the original course, and **Clear selection** resets it.
Searching or switching filters never silently discards hidden selections.
