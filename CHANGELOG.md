# Changelog

This project follows semantic versioning. Versions below 1.0 are previews and may change
save or API formats through documented migrations.

## Unreleased

- Show archived community Best answer lengths in the problem panel, separate from puzzle limits and personal shortest solutions, with an explanation of the source and missing records.
- Add a tappable board legend explaining targets, blocking walls and traversable traps in English, Chinese and Japanese, with matching Modern/Classic symbols. Opening the guide pauses execution.

## [0.3.7] - 2026-10-09

- Replace match modes with unified Match Settings: optional time limit and independent per-model, per-problem input/output token budgets, both off by default, plus three attempts per problem.
- Mark output-cap exhaustion and per-problem budget exhaustion as Burnout. Retain partial responses/reasoning, cancel the current request and remaining retries for that problem, then continue other problems and entrants with fresh budgets.
- Retire per-model output caps. Unlimited requests use advertised output capacity or omit the cap for provider defaults; limited requests share the same match policy. Preserve legacy settings in historical snapshots and migrate active settings to schema 3.
- Enable provider-aware automatic thinking and the highest advertised reasoning effort by default, with a JSON preview and explicit advanced overrides. Keep unknown compatible-provider capabilities uninferred.
- Strip provider prefixes before `:` from displayed model names and move usage notes below puzzle progress. Add the user-provided six-model run and refreshed English screenshots to both READMEs.
- Add transport, engine, settings migration and native Mac UI coverage for unified settings, reasoning defaults and Burnout cancellation.

## [0.3.6] - 2026-10-09

- Treat HTTP 200 in-band provider errors, including `finish_reason: error` / `content_filter`, as request failures instead of invalid H submissions. Preserve partial text, reasoning, finish reasons, usage and credential-redacted error details; do not judge or retry these as incorrect programs.
- Retain network error domains/codes and distinguish incomplete streams from malformed answers. Remove the independent 600-second total transfer timeout while keeping the inactivity timeout, match limits and cancellation.
- Show live waiting/thinking/answer-generation phases and explicit notices on retained interrupted output. Suppress misleading Rejected labels in older provider-error attempts, without rewriting historical scores.
- Add transport, engine, persistence and native Mac UI regressions, plus actual English app captures of thinking, provider failure and network interruption.

## [0.3.5] - 2026-10-09

- Include all 0.3.4 benchmark, streaming and puzzle picker improvements in the published Mac preview.
- Add an explicit SSE parser initializer for older Swift toolchains. The 0.3.4 GitHub release was blocked by a test compilation error before native builds or publishing; its tag is retained without rewriting history.

## [0.3.4] - 2026-10-09

- Display normalized benchmark percentages in progress, history and share images. Move solved counts beside provider names, and omit `(free)` from displayed model names while preserving provider IDs and raw history metadata.
- Stop counting cumulative SSE framing against the old 4 MiB response limit. Bound individual events and decoded content instead, preserve partial responses on failures, and apply the H parser limit to extracted code rather than explanatory prose.
- Redesign puzzle selection with integrated search, original/community/selected filters, chapter groups, board previews, byte budgets and explicit bulk actions. Hidden selections survive searches and source changes.
- Refresh actual English Battlefield screenshots and benchmark methodology documentation.

## [0.3.3] - 2026-10-09

- Raise the default model output allowance to 65,536 tokens, including reasoning. Add a persistent model-parameter shortcut to New match, a 64K reset button, and the provider-declared limit in the editor. Legacy 4K defaults upgrade; other custom settings and historical requests are preserved.
- Best Effort now waits for every AI to finish its attempts. A slower entrant can still win on points or token efficiency; manual Stop cancels active requests.
- Open Mac match history wide enough for three model columns and make history and answer dialogs resizable in both dimensions.
- Use compact icon-and-title Battlefield navigation on iPhone/iPad. Reasoning can collapse independently and uses Markdown headings, lists, emphasis, quotes and fenced code.
- Display the original course continuously as L01–L30. Replace the former L25/L26 with symmetric, walled L07 Turning rose and L08 Tandem lanterns; retain the other boards. Display order is independent of save IDs, and prior board snapshots/retired progress remain readable.
- Update shared prompt identity to `herbert-h-v4` for the renamed course finale, documentation, device checks and actual app screenshots.

## [0.3.2] - 2026-10-08

### Fixed

- Retain final responses, model reasoning and partial streamed text in live answer details
  and match history. Expand full responses by default and update already-open dialogs.
- Preserve bounded, credential-redacted provider error bodies instead of discarding HTTP
  400 diagnostics. Explain reasoning-only output-cap exhaustion without showing empty programs.
- Replay `reasoning_content` / `reasoning` on rejected-answer retries and avoid empty assistant
  turns after reasoning-only replies. Allow provider-specific `thinking` parameters.

### Changed

- Upgrade the shared H prompt to `herbert-h-v3`, adding coordinate rulers, explicit target
  coordinates, termination/reuse explanations and two complete native-verified teaching boards.
  The recursive example is separate from L50 and other scored puzzles.
- Condense L01–L30 into ten selected lessons; retain L31–L50, totaling 30 original puzzles
  and 1,799 in the community edition. Only the first two can fit a direct primitive program.
  Keep retained IDs/layouts/budgets stable and preserve retired records in backups/history.
- Refresh English/Chinese documentation, Herbert Benchmark methodology and native app captures.

## [0.3.1] - 2026-10-08

### Changed

- Merge AI Providers into Battlefield's title-bar navigation, leaving four main tabs.
  Mac setup places entrants and puzzles side by side; shared Markdown rules render with
  headings, readable paragraphs and H code examples.
- Make puzzle progress the live ranking: score-sorted model columns with token/cache
  headers, corner error indicators, compact two-line answers and unrestricted panel width.
- Quantify scores from final target coverage and H code length, keeping the best attempt
  per puzzle and breaking ties by total tokens then completion time. Versioned histories
  preserve the 0.3.0 scoring and ordering.
- End Best Effort when the first entrant completes the entire selected puzzle schedule,
  including exhausted retries; cancel outstanding calls and save all judged results.

### Added

- Open every submitted program in the actual game board for an editable trial and return
  to current or historical results. Trials preserve personal drafts, shortest solutions
  and competition scores.
- Herbert Benchmark documentation, scoring examples and refreshed English app captures,
  plus regressions for partial scores, trap resets, history compatibility and race cancellation.

## [0.3.0] - 2026-10-08

### Added

- Independent AI Providers and AI Battlefield tabs in both editions, localized in English,
  Simplified Chinese and Japanese.
- Multiple OpenRouter, SiliconFlow and OpenAI compatible connections, authenticated model
  discovery, default entrants, per-model sampling/output/reasoning parameters and Keychain keys.
- Parallel competitions with identical rules/board prompts, the 50 originals selected by
  default, configurable retries, time limits, shared/per-model token budgets and Best Effort.
- Native H judging, failure feedback, live score ranking, per-puzzle inspection, streaming
  input/output usage, cache rates, cancellation and local match history with crash recovery.
- PNG result cards rendered locally and shared through the system share sheet.
- Separate UI-independent `HerbertBattlefield` package, engine/HTTP integration tests,
  native UI coverage, privacy disclosures and Mac outgoing-network entitlement audits.

### Notes

- AI is optional and uses your own provider credits. Live token estimates and cancellation
  cannot guarantee final provider billing. iOS backgrounding ends a match and saves results.
- Game progress and the 50/1,769 puzzle packaging boundary are unchanged.
- Mac previews remain ad-hoc signed and unnotarized; iPhone/iPad runtime checks require devices.

## [0.2.0] - 2026-10-08

### Added

- Universal macOS DMG packaging with mounted-image audits, SHA-256 checksums,
  downloadable Actions artifacts, and automatic tagged preview releases.
- 50 independently designed MIT lessons in ten stages, including 20 advanced walled
  challenges with parameter swaps, recursive returns, mutual recursion and composition. Three-language goals and
  progressive hints; every reference program is verified with the real H engine.
- `HerbertAppStore`, bundling only original lessons. Default `Herbert` contains 1,819
  problems, with the 1,769-problem community archive in an optional module.
- Community #0001–#0020 study, eight verified solutions, independent geometric oracles,
  and regressions against two discovered fixed-loop shortcuts. New localized app captures
  showcase the advanced course.
- Final iOS/Mac store-bundle resource audits, original course documentation and device checks.
- Ignored local signing configuration shared by both schemes.
- Automatic English, Simplified Chinese, and Japanese localization, including guide,
  accessibility descriptions, and interpreter/storage errors; English fallback.
- Movement trails that retain every walked edge at all speeds, with bounded memory.
- Classic board inspired by the original rules-page screenshot, alongside Modern (default).
- Continuous wall outlines in Modern and Classic, preserving holes and diagonal separation.
- Persistent board settings for style, movement trail, and per-cell grid dots.
- Translation coverage/format checks and native UI tests for languages and preferences.

### Fixed

- Correct community board decoding: `x` is a wall and `*` is a trap. Original lessons
  use the same encoding without changing their designed layouts.
- Pinned HOJ compatibility audit, 17 differential language fixtures, and collision,
  trap recovery, immediate completion and scoring regression tests.

## [0.1.0] - 2026-10-07

### Added

- Native SwiftUI game for iPhone, iPad, and Mac, with adaptive board/editor layouts.
- Independent H parser and virtual machine, original byte counting, and bounded execution.
- Offline snapshot of 1,769 original problems with authors, IDs, limits, and provenance.
- Run/pause, single-step, speed controls, zoom, search, favorites, and a Chinese guide.
- Local draft/solution saves, atomic JSON persistence, and validated backup import/export.
- Unit/integration tests, native Mac UI tests, and reproducible app screenshots.
- MIT licensing for original code, bilingual documentation, community templates, and CI.

### Known limits

- Original puzzle archive rights are separate from the code license; redistribution
  permission has not been confirmed. See [NOTICE.md](NOTICE.md).
- iOS compilation is verified; phone/tablet runtime validation remains open.
- The UI is Simplified Chinese. There is no cloud sync, online leaderboard, App Store
  release, or notarized Mac binary.

[0.3.7]: https://github.com/hugogu/herbert/releases/tag/v0.3.7
[0.3.6]: https://github.com/hugogu/herbert/releases/tag/v0.3.6
[0.3.5]: https://github.com/hugogu/herbert/releases/tag/v0.3.5
[0.3.4]: https://github.com/hugogu/herbert/tree/v0.3.4
[0.3.3]: https://github.com/hugogu/herbert/releases/tag/v0.3.3
[0.3.2]: https://github.com/hugogu/herbert/releases/tag/v0.3.2
[0.3.1]: https://github.com/hugogu/herbert/releases/tag/v0.3.1
[0.3.0]: https://github.com/hugogu/herbert/releases/tag/v0.3.0
[0.2.0]: https://github.com/hugogu/herbert/releases/tag/v0.2.0
[0.1.0]: https://github.com/hugogu/herbert/releases/tag/v0.1.0
