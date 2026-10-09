<p align="center">
  <img src="Herbert/Assets.xcassets/AppIcon.appiconset/mac-128@2x.png" width="96" alt="Herbert robot icon">
</p>

<h1 align="center">Herbert</h1>
<p align="center">A little robot. A big idea. Find the shortest program through a world of patterns.</p>
<p align="center">
  <a href="https://github.com/hugogu/herbert/actions/workflows/ci.yml"><img src="https://github.com/hugogu/herbert/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src=".github/badges/license-mit.svg" alt="Code license: MIT"></a>
  <img src="https://img.shields.io/badge/Swift-6.0-F05138" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/platforms-iOS_17%2B_%7C_macOS_14%2B-31454B" alt="iOS 17+ and macOS 14+">
</p>
<p align="center"><b>English</b> · <a href="README.zh-CN.md">简体中文</a> · <a href="CONTRIBUTING.md">Contribute</a> · <a href="CHANGELOG.md">Changelog</a></p>

Herbert is an offline programming puzzle game for **iPhone, iPad, and Mac**, built with
SwiftUI. Guide the robot to every target using H, a tiny language whose short programs
can express surprisingly intricate paths. Learn three commands, discover recursion,
and keep making your solution smaller.

Start with **10 introductory lessons**, then explore **20 advanced challenges** in
wall-assisted counting, parameter swaps, recursive returns, mutual recursion and
composition. All **30 original puzzles** have English, Chinese and Japanese goals
and two optional hints, with reference programs verified by the native and HOJ engines.
The default open-source edition also includes **1,769 community problems**, preserving
their IDs, authors and byte limits. The **App Store edition contains only the 30 originals**.
The course uses continuous **L01–L30** numbers: ten introductory lessons followed
by twenty advanced challenges. Only the first two fit a direct sequence of commands.
L07 “Turning rose” and L08 “Tandem lanterns” are newly designed symmetric, walled boards.
Display numbers are separate from internal save IDs; retired records remain importable.

## Download for Mac

**[Download the 0.3.7 preview DMG](https://github.com/hugogu/herbert/releases/download/v0.3.7/Herbert-macOS-universal.dmg)**
— macOS 14+, Apple Silicon and Intel. Open the DMG and drag Herbert to Applications;
no Xcode is needed. Includes all 1,799 problems.

This preview is ad-hoc signed and **not Apple notarized**. macOS may block its first
launch; follow [Apple's instructions](https://support.apple.com/en-us/102445) for
**System Settings → Privacy & Security → Open Anyway** if you trust the download.
See [checksums, installation and build details](docs/macos-distribution.md).

[Explore the original curriculum](docs/original-course.md) · [Design and community study](docs/advanced-course-design.md) · [App Store build and device testing](docs/app-store.md)

![Herbert original course in the English Mac app: Vaulted mosaic](docs/screenshots/en/course/course-mosaic.png)

*Actual native macOS App Store edition with English UI. L29 “Vaulted mosaic” combines
shrinking tiers, window patterns and fourfold rotation. Its nested procedures must
return to their starting position and heading before the next pattern can fit.
The app follows English, Simplified Chinese, or Japanese language preferences; other
languages fall back to English.*

## Small programs, intricate places

The six-chapter [original course](docs/original-course.md) grows from a single `s` to
layered recursive systems. Walls reveal rooms, folds and rotational units while
constraining the route. These are three of the new challenges; click a board for its
full game screen:

| L18 · Hinged rosette | L24 · Snowmelt seal | L30 · Astral cathedral |
| --- | --- | --- |
| [![Hinged rosette board with four walled spiral arms](docs/screenshots/en/course/course-rosette-board.png)](docs/screenshots/en/course/course-rosette.png) | [![Snowmelt seal board with recursive folds and four trap caps](docs/screenshots/en/course/course-seal-board.png)](docs/screenshots/en/course/course-seal.png) | [![Astral cathedral board with branching square courtyards](docs/screenshots/en/course/course-cathedral-board.png)](docs/screenshots/en/course/course-cathedral.png) |
| Recursive return · ≤ 29 bytes | Selective instruction expansion · ≤ 34 bytes | Chiral branching + composition · ≤ 56 bytes |

*These original puzzles and their screenshots are MIT licensed. Budgets are verified
achievable, not proven minima. Our [community study and design notes](docs/advanced-course-design.md)
explain the progression and the simple-loop shortcuts removed during design.
The course is included in the Mac preview.*

| L07 · Turning rose | L08 · Tandem lanterns |
| --- | --- |
| [![Four symmetric folded petals with continuous walls](docs/screenshots/en/course/course-rose-board.png)](docs/screenshots/en/course/course-rose.png) | [![Paired square lanterns joined by a lower bridge](docs/screenshots/en/course/course-lanterns-board.png)](docs/screenshots/en/course/course-lanterns.png) |

## AI Battlefield

**Updated in 0.3.7:** one **Match Settings** panel replaces match modes. Time and
per-problem token limits are optional and off by default; each problem allows three
attempts by default. Every model receives the same per-problem budget. Reaching an
output or token limit marks that problem **Burnout**, retains received reasoning and
cancels its remaining retries. Other problems and entrants continue.

- Add multiple OpenRouter, SiliconFlow, Google Gemini or OpenAI compatible providers. Discover models
  through `/models`, choose default entrants, and save settings locally. API keys stay
  in the system Keychain.
- **Model Settings** covers sampling and advanced parameters. Automatic thinking is on
  by default, using the highest advertised reasoning effort for supported models.
  Explicit advanced JSON overrides these defaults. Output allowances come from the
  shared match policy and provider capabilities, without a separate model cap.
- Choose models and puzzles; models work in parallel with identical Markdown rules
  and board prompts. With limits off, all entrants can finish their selected attempts.
- Mac setup places entrants and puzzles side by side. Progress uses compact two-line
  answers and score-sorted model columns. Saved results open as a full page in the
  History tab and expand with the main window. A persistent Back action returns to
  the history list; answer dialogs remain resizable. iPhone uses short icon tabs.
- Model headers show normalized percentages with total points as a reference,
  input/output/total tokens and cache rates. Each attempt has its own elapsed timer;
  live timers advance and finished durations remain fixed in history.
  Provider prefixes and `(free)` are omitted from display names. Select an answer to
  inspect submissions, native feedback and retries, then **Try on board** with code
  prefilled. **Back to match** returns to the results, preserving personal progress.
- Full response retains final text, independently collapsible Markdown reasoning and
  credential-redacted errors. Live attempts show **Thinking**, **Generating answer**
  or **Waiting for provider**. Provider and network failures are distinct from rejected
  H programs; retained reasoning is explicitly marked when generation has ended.
- Shared prompt `herbert-h-v4` includes coordinate rulers, target coordinates and two
  native-verified worked boards, including a recursive pinwheel separate from scored L30.
- Stop cancels active calls. Matches save locally and can be shared as PNG cards.
  Token accounting notes sit below puzzle progress.

AI is optional and uses **your own API credits**. Streaming usage can be estimated or
partial; token budgets cannot guarantee a provider's final bill. iPhone/iPad matches end
when the app enters the background. [Setup and accounting](docs/ai-battlefield.md) · [Privacy](PRIVACY.md).

## Herbert Benchmark

Use the **30 retained original puzzles** as an AI programming benchmark: movement and
walls, numeric and instruction parameters, recursion, multiple procedures and their
composition. Every answer runs in the same bounded native H engine used for human play.
The platform measures actual board outcomes and code length, with no model acting as judge.

**Score per attempt = target coverage × (80 + 20 × code savings)**, where coverage is
final lit targets / total targets, and code savings is `1 − H bytes / puzzle byte limit`.
Round to two decimals, keep the best attempt per puzzle, and sum the scores.
Display the benchmark as **total points / (100 × selected puzzles) × 100%**:
160 points over eight puzzles is **20%**. Unsolved puzzles remain in the denominator;
this measures coverage and code efficiency, rather than the fraction of solved puzzles. Compile-invalid
and over-limit programs earn zero; incomplete runs can earn partial points. Traps reset
coverage. A shorter accepted program earns more points. Robot steps do not affect score.
Rank by **score descending → total input + output tokens ascending → completion time**.
Cached input and all retries count toward token consumption. Older 0.3.0 histories retain
their original 100-per-solved-puzzle scoring and tie-breaks.

For repeatable comparisons, use the same puzzle set, attempts, Match Settings and shared
prompt, and record sampling/reasoning parameters. The optional **per-model, per-problem
token budget** covers input and output across retries. With both limits off, every entrant
can finish without a match deadline or app-imposed output cap. Known provider output
limits still apply; unknown limits use provider defaults.
History snapshots preserve the full shared prompt and its version, boards, parameters, received answers and the scoring policy;
provider model versions can still change. This composite score is our benchmark policy,
inspired by the original site's shortest-code ranking. [Scoring and limits](docs/ai-battlefield.md#judge-and-rank).

![User-provided Herbert Benchmark run showing six LLMs side by side](docs/screenshots/en/battlefield/herbert-benchmark-user-run.png)

*User-provided English app capture of six models over a ten-puzzle selection. Several
answers were stopped; this is an illustrative run, not a completed controlled comparison.
The capture predates 0.3.7, so its model names still include provider prefixes.*

[Current progress UI](docs/screenshots/en/battlefield/ai-battlefield.png) ·
[New match](docs/screenshots/en/battlefield/ai-new-match.png) ·
[Match Settings](docs/screenshots/en/battlefield/ai-match-settings.png) ·
[Model Settings](docs/screenshots/en/battlefield/ai-model-settings.png) ·
[Puzzle selection](docs/screenshots/en/battlefield/ai-puzzles.png) ·
[Readable rules](docs/screenshots/en/battlefield/ai-rules.png) ·
[Providers](docs/screenshots/en/battlefield/ai-providers.png) ·
[Models](docs/screenshots/en/battlefield/ai-models.png) ·
[Full-page three-AI history](docs/screenshots/en/battlefield/ai-history.png) ·
[Native feedback](docs/screenshots/en/battlefield/ai-answer.png) ·
[Burnout and retained reasoning](docs/screenshots/en/battlefield/ai-burnout.png) ·
[Provider error details](docs/screenshots/en/battlefield/ai-provider-error.png) ·
[Live thinking](docs/screenshots/en/battlefield/ai-thinking.png) ·
[Interrupted provider stream](docs/screenshots/en/battlefield/ai-stream-error.png) ·
[Network diagnostics](docs/screenshots/en/battlefield/ai-network-error.png) ·
[Board trial](docs/screenshots/en/battlefield/ai-trial.png) ·
[PNG share preview](docs/screenshots/en/battlefield/ai-share.png)

*Linked UI captures use deterministic test entrants and demonstrate the current app.
Their scores are illustrative, not commercial model results.*

## Community patterns

The default open-source edition also includes the archived community collection.
These examples are excluded from the App Store edition. Search their IDs in `Herbert`:

The problem panel shows the **original best reference** separately from the byte limit
and your personal shortest solution. These are archived `Best` lengths from the
[original problem list](http://herbert.tealang.info/problems.php), not live records
or proven minima; unavailable entries show **No record**. For example, #0027 allows
39 bytes and has an archived best of 14 bytes.
[See the problem panel](docs/screenshots/en/community-reference.png).

Tap the board legend to learn the symbols in either Modern or Classic style:
**walls block movement**, while **traps can be entered but turn off all lit targets**.
Both continue the program; traps leave the robot on the trap.
[See the board guide](docs/screenshots/en/community-board-guide.png).

<table>
  <tr>
    <td align="center" width="33%"><a href="docs/screenshots/en/flower.png"><img src="docs/screenshots/en/flower-board.png" alt="Flower puzzle: four petals inside a square field of traps" width="280"></a></td>
    <td align="center" width="33%"><a href="docs/screenshots/en/shuriken.png"><img src="docs/screenshots/en/shuriken-board.png" alt="Shuriken puzzle: a four-armed rotational pattern" width="280"></a></td>
    <td align="center" width="33%"><a href="docs/screenshots/en/butterfly.png"><img src="docs/screenshots/en/butterfly-board.png" alt="Butterfly puzzle: mirrored wings made from targets and traps" width="280"></a></td>
  </tr>
  <tr>
    <td align="center"><b>#0037 · Flower</b><br>nai · ≤ 20 bytes</td>
    <td align="center"><b>#0027 · Shuriken</b><br>snuke · ≤ 39 bytes</td>
    <td align="center"><b>#0361 · Butterfly</b><br>nadsuki · ≤ 27 bytes</td>
  </tr>
</table>

*These are board screenshots from the running app. Click a board to see its full game screen.*

## Modern or Classic

<table>
  <tr>
    <td align="center"><a href="docs/screenshots/en/course/course-mosaic.png"><img src="docs/screenshots/en/course/course-mosaic-board.png" width="380" alt="Modern Vaulted mosaic board with continuous walls and amber targets"></a></td>
    <td align="center"><a href="docs/screenshots/en/course/course-mosaic-classic.png"><img src="docs/screenshots/en/course/course-mosaic-classic-board.png" width="380" alt="Classic Vaulted mosaic board with black walls, white targets, red robot and blue trail"></a></td>
  </tr>
  <tr><td align="center">Modern · default</td><td align="center">Classic · movement trail</td></tr>
</table>

*Both are actual app captures of original lesson L29. Classic follows the original
rules-page board appearance. Its screenshot follows three successful moves. Adjacent
walls share a continuous outline in both styles. Use the sliders button above the board
to change style, grid dots, and trail visibility.*

<details>
<summary>Explore the original course library</summary>

![Original-only Herbert library with search, progress, filters, and live board thumbnails](docs/screenshots/en/course/course-library.png)

</details>

## What you can do

- **Learn one idea at a time.** Follow the 30-lesson course from one step to the Astral cathedral;
  reveal hints individually when you need them. Titles, goals and hints support all three languages.
- **Play anywhere offline.** The default edition bundles 1,799 problems; the App Store
  edition bundles 30 originals. Search by ID, title, or author;
  bookmark favorites and return to your last problem.
- **Think in H.** Use `s`, `l`, and `r`, then build single-letter procedures, numeric and
  command parameters, and recursive programs. Original byte-counting rules are preserved.
  See the [HOJ compatibility audit](docs/hoj-compatibility.md) for tested behavior and limits.
- **Watch your idea unfold.** Run, pause, reset, or single-step. Change speed, zoom the board,
  and switch between the full 25 × 25 grid and its occupied region. See the robot’s complete
  movement trail, including at Turbo speed.
- **Make the board yours.** Open the sliders button above the board to choose Modern
  (default) or Classic, show/hide grid dots for counting cells, and toggle the movement
  trail. Preferences stay on this device. Resetting or editing code clears the trail;
  hiding it keeps recording.
- **Play in your language.** English, Simplified Chinese, and Japanese cover navigation,
  the guide, accessibility, and interpreter errors. Community puzzle titles/authors are preserved.
- **Use a layout that fits.** Stacked board and editor on phones; side-by-side play on iPad
  and Mac. Native text editing, cursor-aware command buttons, and `⌘ Return` on Mac.
- **Keep your progress.** Drafts, favorites, and shortest solutions save locally. Export JSON
  backups and merge them back after their solutions have been replayed and validated.
- **Keep your privacy.** No app accounts, analytics SDKs or ads. Human play stays offline;
  optional AI requests go directly to the providers you configure. [Data details](PRIVACY.md).

## Try your first program

Open lesson **L01 · First light** and enter:

```text
s
```

Each `s` moves forward one square; `l` turns left and `r` turns right. Light every amber
ring within the problem's byte limit. Walls block movement. Traps erase lit targets.

The challenge is program size, not the number of steps. Each letter and each numeric
literal counts as one byte: `12` is one byte, and punctuation and whitespace are free.
The in-app guide introduces procedures and recursion; [rule notes](docs/rules.md) explain
the full language and compatibility limits. Programs execute in the custom H interpreter,
with bounded execution; they do not execute Swift or shell commands.

## Build and run

You need **macOS and Xcode 16+ with Swift 6**. The checked-in Xcode project uses a local
Swift package and has **no third-party package dependencies**. Xcode 27.0 is the locally
verified toolchain; CI uses the default Xcode on the macOS 26 runner.

```sh
git clone git@github.com:hugogu/herbert.git
cd herbert
open Herbert.xcodeproj
```

Choose the **Herbert** scheme and your Mac, iPhone, or iPad destination, then Run.
For a physical iOS device, select your own Development Team in Signing & Capabilities.
No developer account is configured in the repository.

| Scheme | Included content | Intended use |
| --- | --- | --- |
| `Herbert` (default) | 30 original lessons + 1,769 archived community puzzles | Open-source edition |
| `HerbertAppStore` | 30 original lessons only | TestFlight / App Store candidate |

The community archive is a separate optional Swift package target, not a runtime-hidden
file in the store app. CI audits built iOS and Mac store apps for content isolation.
Personal signing settings can go in ignored `Config/Local.xcconfig` as `DEVELOPMENT_TEAM = YOUR_TEAM_ID`.
See [device and archive instructions](docs/app-store.md) before uploading.

```sh
# Formatting, importer unit tests, and core unit/integration tests
scripts/check.sh

# Build the native Mac app
xcodebuild -project Herbert.xcodeproj -scheme Herbert \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY=- build

# Compile for iPhone and iPad without signing
xcodebuild -project Herbert.xcodeproj -scheme Herbert \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Run native Mac UI tests (uses a separate test save file)
xcodebuild -project Herbert.xcodeproj -scheme Herbert \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY=- test
```

**Status: early preview.** Core tests, native Mac UI flows, and iOS compilation have been
verified. iPhone/iPad runtime and real-device testing remain open; there is no App Store
or notarized binary release yet. See [verification details](docs/verification.md).

## How it is built

| Location | Responsibility |
| --- | --- |
| `Herbert/` | SwiftUI screens, native editors, animation, app state |
| `Sources/HerbertCore/` | UI-independent H parser, VM, board, session, progress storage |
| `Sources/HerbertCommunity/` | Optional community archive, excluded from App Store targets |
| `Sources/HerbertBattlefield/` | Provider protocol, streaming client, parallel competition engine, judging and local history |
| `Tests/HerbertCoreTests/` | Language unit tests and game/save/backup integration tests |
| `Tests/HerbertBattlefieldTests/` | AI engine, budgets, cancellation, persistence and HTTP/SSE integration tests |
| `HerbertUITests/` | Native UI tests and reproducible screenshot captures |
| `scripts/` | Project/icon generation, validated catalog import, local checks |
| `docs/` | Rules, provenance, architecture, screenshots, verification |

`HerbertCore` can be built and tested independently with `swift test`.
After adding or removing app Swift files, run `python3 scripts/generate_project.py`.
Generated project files are checked in; contributors do not need XcodeGen.

Progress goes through `ProgressRepository` into an atomic, versioned JSON file in the
system-provided Application Support directory. Cloud sync is planned, not implemented:
**App → authenticated Cloudflare Worker → D1**. Database credentials will stay out of
clients. Read the [architecture notes](docs/architecture.md) for merge and migration rules.

## Contributing

Bug reports, documentation improvements, localization, accessibility work, and device
testing are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks, and places
to start. For feature ideas, open an issue before a large implementation.

- [Report a bug](https://github.com/hugogu/herbert/issues/new?template=bug_report.yml)
- [Suggest an improvement](https://github.com/hugogu/herbert/issues/new?template=feature_request.yml)
- [Browse good first issues](https://github.com/hugogu/herbert/labels/good%20first%20issue)
- [Code of conduct](CODE_OF_CONDUCT.md) · [Security policy](SECURITY.md)

### Next steps

- Test and refine phone keyboard, rotation, touch, and accessibility behavior on devices.
- Refine English/Japanese translations while preserving original puzzle titles and author credits.
- Expand H compatibility fixtures and make execution easier to inspect.
- Finish device testing and App Store privacy/metadata preparation using the original-only scheme.
- Add optional authenticated cloud sync while keeping offline play first.

## Credits and license

Inspired by [Herbert Online Judge](http://herbert.tealang.info/), created by **quolc**, and
its problem authors. Original [rules](http://herbert.tealang.info/rule.php) and
[problem collection](http://herbert.tealang.info/problems.php) are linked for attribution.
The original Flash client, online accounts, submissions, and leaderboard are not included;
original best scores are an import-time snapshot, not live rankings.

Our source code, 30 original lessons, original icon, and documentation use the **[MIT License](LICENSE)**.
Third-party community puzzle data and community layouts visible in screenshots are
**not relicensed under MIT**. See [NOTICE.md](NOTICE.md) for the precise scope and provenance.
