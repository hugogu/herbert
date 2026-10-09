# AI Battlefield

Available in both editions from **0.3.0**, refined in **0.3.7**. The app has four main
tabs; **AI Battlefield** contains **AI Providers**, **New match**, **Current match** and
**Match history** in its title bar. The ordinary puzzle game remains fully offline.

## Connect models

1. In **AI Battlefield → AI Providers**, add OpenRouter, SiliconFlow, or an OpenAI compatible provider.
2. Enter its HTTPS base URL and your own API key. Saving automatically requests
   `GET /models`; SiliconFlow adds `sub_type=chat` to discover chat models.
3. Select any default entrants. Configure each model's optional temperature, top P, automatic thinking
   and supported advanced JSON parameters. Blank sampling values use provider defaults.
4. Use **Refresh models** after provider permissions or model availability change.

The base URL ends at the API version, for example `https://openrouter.ai/api/v1` or
`https://api.siliconflow.cn/v1`; do not append `/models` or `/chat/completions`.
The standard discovery endpoint is plural **`/models`**, not `/model`.
Custom endpoints must support OpenAI-style chat completions. Choose `max_tokens` or
`max_completion_tokens` according to that provider. Authentication uses the Bearer header.
Redirects are rejected; enter the final URL directly. HTTP endpoints are not accepted.

**Match Settings** controls output allowances for every entrant; there is no per-model
output-cap editor. With token limits off, requests use the provider-declared maximum
output capacity, bounded by the remaining context when both limits are known. If no
maximum is advertised, Herbert omits `max_tokens` / `max_completion_tokens` and lets the
provider choose its default. “Unlimited” removes the app's arbitrary cap; it cannot
infer undocumented model capacity or override a provider's limits/defaults.

Automatic thinking is **enabled by default** in Model Settings. OpenRouter uses
`reasoning: {enabled: true, effort: ...}` for models advertising reasoning support,
choosing the first/highest `reasoning.supported_efforts` value or `max` when the model
advertises reasoning without listing levels. SiliconFlow defaults to
`enable_thinking: true`, with `reasoning_effort: max` for its documented DeepSeek V4 /
GLM-5.2 models or models advertising effort control. Compatible providers receive only
advertised thinking fields; an effort field without advertised levels uses `high`.
Unsupported/undiscovered reasoning capabilities are not guessed for arbitrary endpoints.
The editor previews the automatic JSON. Explicit reasoning-family values in advanced
JSON replace the automatic reasoning defaults as a group, so you can use a provider's
specific settings without conflicting injected fields. Support varies by model:
SiliconFlow effort defaults are limited to models with advertised or documented support;
other models receive the thinking switch. Override defaults if your endpoint needs different options. See
[OpenRouter reasoning](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)
and [SiliconFlow parameters](https://api-docs.siliconflow.cn/docs/api/chat-completions-post).

Settings schema 3 retires saved per-model caps and old aggregate budgets for new matches.
Sampling, explicit advanced JSON, chosen entrants and attempt counts remain; an old timed
setting keeps its deadline enabled. Old shared/per-model aggregate budgets are not silently
reinterpreted as per-problem limits. Historical files, scores, legacy modes, budgets and
actual requested caps remain available in snapshots without being rewritten on load.

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

Live attempts distinguish **Waiting for provider**, **Thinking** and **Generating answer**.
After a request ends, retained reasoning is explicitly marked as partial received text;
its wording does not imply that generation is still running. A completed, invalid H
submission is **Rejected** by the native judge. A provider failure is **Request failed**
and is not judged or sent back as an incorrect program. Old attempts with
`finish_reason: error` also suppress the misleading Rejected presentation.

HTTP 200 can still contain a provider error. Both JSON and SSE replies recognize
top-level/choice errors and `finish_reason: error` or `content_filter`, preserving partial
text, reasoning, usage, finish reason and redacted diagnostics. This follows
[OpenRouter's documented in-stream error protocol](https://openrouter.ai/docs/api_reference/errors-and-debugging).
Network failures retain their domain and code (for example `NSURLErrorDomain -1005`
for a lost connection), rather than only saying “AI request failed”. An EOF without a
finish reason or `[DONE]` is reported as an incomplete stream. Provider/transport errors
stop that entrant, without spending further paid requests on an automatic retry; other
entrants continue. Historical generic errors cannot recover missing network diagnostics.

A `finish_reason: length` reply means the provider exhausted the request's output
allowance. That problem becomes **Burnout**, with no second request or invalid-program
judgment for the truncated response. Received text, reasoning, usage and finish reason
remain inspectable. A local per-problem budget also cancels the active request and
remaining retries for that problem. The same entrant continues with a fresh budget on
the next problem, while other entrants proceed independently. Earlier judged attempts
retain their best score. Burnout is not an automatic paid retry.

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

There are no separate modes. **Match Settings** combines:

| Setting | Default | Behavior |
| --- | --- | --- |
| Limit match time | Off | If enabled, a monotonic deadline cancels all requests and local judging. Editable starting value: 600 seconds. |
| Limit tokens per problem | Off | If enabled, each model gets the same independent budget per problem, across all attempts, including input, output and reasoning. Editable starting value: 100,000 tokens. |
| Maximum attempts per problem | 3 | From 1 to 10. Completed, rejected H answers receive native feedback and another attempt while budget remains; Burnout cancels the remaining attempts for that problem. |

Both limits can be enabled together. Budgets are not shared across models or problems.
If the next prompt cannot fit the remaining problem budget, no request is sent and the
problem becomes Burnout. At exactly the limit, an already completed answer may still be
judged; incomplete or over-budget output is not judged. Without limits, every entrant
can solve or exhaust its attempts on all selected puzzles; an early finisher does not
cancel others. Every match can finish naturally or be stopped by the user.

Completion requests keep a
600-second **inactivity** timeout, reset by incoming data, and use Foundation's default
multi-day total resource timeout. The previous independent 600-second total transfer
deadline could interrupt a model still streaming reasoning; 0.3.6 removes that override.
The optional time limit, per-problem budget and Stop cancel the corresponding active requests. Model discovery
has a 30-second inactivity timeout. See Apple's
[request timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest)
and [resource timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforresource).
Authentication,
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
Solved counts sit alongside provider names. Provider prefixes before the first `:` and
pricing suffixes such as `(free)` are omitted from model display names; request IDs and saved provider metadata remain intact. Errors appear in
a corner indicator. Total points appear beside the primary normalized percentage.
Two-line cells show status, attempt, points, elapsed time and a program preview.
While a request is active, the cell follows the current attempt; after completion it
shows the best-scoring attempt. Answer details give every retry its own elapsed timer.
Live timers update each second; finished attempts retain their recorded durations in
history. A recovered interrupted attempt ends at the last saved checkpoint, excluding
time spent away from the app. Existing start/end timestamps are reused without a save migration.
Select a cell to inspect every submitted answer and its feedback. **Try on board** opens
the actual puzzle snapshot with the answer prefilled; **Back to match** returns to the
results, including from history. Trials can be edited and replayed without modifying
personal drafts, shortest solutions or stored competition results. The table fills the
available window width, with horizontal scrolling for additional models.

For comparable measurements, keep puzzle sets, attempts, Match Settings and shared
prompts fixed; record sampling/reasoning parameters. Equal per-model, per-problem token
budgets suit resource comparisons. With limits off, every entrant can finish its selected
attempts. A slower entrant can still overtake an early finisher on points or token efficiency.
Provider failures stop only the affected entrant; other entrants continue. Histories retain
boards, the full shared prompt, model parameters, match limits and scoring policy. Remote
model versions and provider routing can still change; snapshots do not make a third-party
model deterministic.

## Understand token accounting

Providers often return exact usage only at the end of a stream. During generation,
Herbert estimates tokens from UTF-8 bytes and includes prompt/message overhead; **≈**
means estimated or partial usage. Final reported usage replaces estimates rather than
being added a second time. Output includes reasoning tokens; they are not double-counted.
Input cache rate is cached input / total input and appears only when **every attempt**
reports complete cache usage. Missing data displays **Unavailable**, distinct from 0%.

A limited request receives an output allowance no larger than its remaining problem
budget minus estimated input and any known model capacity/context constraints. Each
entrant's attempts are tracked separately; retries spend the same problem budget. Live
usage reaching the budget cancels that request and marks Burnout. Provider token-cap
semantics vary: reasoning may share the output cap or use a separate provider budget.
Reported final usage takes precedence over local estimates. The accounting note appears
below the progress table.

Stopping cancels underlying URLSession tasks and prevents late answers from receiving
points. **A token budget is not a billing guarantee**: tokenizers differ, an aborted
request may lack final usage, and a remote provider can continue processing after local
cancellation. Check provider usage and use provider-side spending limits for a hard
financial cap.

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

Unit tests exercise native judging, bounded retries, parallelism, optional deadlines,
independent cumulative per-problem budgets, Burnout cancellation, unlimited output,
reasoning defaults, legacy migration, persistence and corrupt data. HTTP integration tests use
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
