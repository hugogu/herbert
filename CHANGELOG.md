# Changelog

This project follows semantic versioning. Versions below 1.0 are previews and may change
save or API formats through documented migrations.

## Unreleased

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

[0.2.0]: https://github.com/hugogu/herbert/releases/tag/v0.2.0
[0.3.0]: https://github.com/hugogu/herbert/releases/tag/v0.3.0
[0.1.0]: https://github.com/hugogu/herbert/releases/tag/v0.1.0
