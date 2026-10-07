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

This independent port includes **1,769 original problems**, with their IDs, authors,
and byte limits preserved. Application code is MIT licensed; the original puzzle archive
has a separate, unconfirmed licensing status explained in [NOTICE.md](NOTICE.md).

![Herbert running natively on macOS: Flower with the board, H editor, and execution controls](docs/screenshots/en/flower.png)

*Actual native macOS app with the English UI, showing #0037 “Flower” by nai. The editor contains a starter
program, not a solution to this puzzle. The app automatically matches English, Simplified Chinese, or Japanese to your preferred language; other languages fall back to English.*

*Language and board options are available on `main` and will be included in the next release.*

## Patterns worth exploring

From a four-step introduction to intricate geometric puzzles, the original collection
rewards recognizing a pattern before writing a program. Search these IDs in the app:

<table>
  <tr>
    <td align="center" width="33%"><a href="docs/screenshots/en/flower.png"><img src="docs/screenshots/en/flower-board.png" alt="Flower puzzle: four petals inside a square field of walls" width="280"></a></td>
    <td align="center" width="33%"><a href="docs/screenshots/en/shuriken.png"><img src="docs/screenshots/en/shuriken-board.png" alt="Shuriken puzzle: a four-armed rotational pattern" width="280"></a></td>
    <td align="center" width="33%"><a href="docs/screenshots/en/butterfly.png"><img src="docs/screenshots/en/butterfly-board.png" alt="Butterfly puzzle: mirrored wings made from targets and walls" width="280"></a></td>
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
    <td align="center"><a href="docs/screenshots/en/flower.png"><img src="docs/screenshots/en/flower-board.png" width="380" alt="Modern Flower board with mint robot and amber targets"></a></td>
    <td align="center"><a href="docs/screenshots/en/flower-classic.png"><img src="docs/screenshots/en/flower-classic-board.png" width="380" alt="Classic Flower board with black walls, white targets, red robot and blue trail"></a></td>
  </tr>
  <tr><td align="center">Modern · default</td><td align="center">Classic · movement trail</td></tr>
</table>

*Both are actual app captures of #0037. Classic follows the original rules-page board
appearance. Its screenshot follows four instructions; only successful moves leave a trail.
Use the sliders button above the board to change style, grid dots, and trail visibility.*

<details>
<summary>Explore the problem library</summary>

![Herbert library with search, progress, filters, and live board thumbnails](docs/screenshots/en/library.png)

</details>

## What you can do

- **Play anywhere offline.** All 1,769 problems are bundled. Search by ID, title, or author;
  bookmark favorites and return to your last problem.
- **Think in H.** Use `s`, `l`, and `r`, then build single-letter procedures, numeric and
  command parameters, and recursive programs. Original byte-counting rules are preserved.
- **Watch your idea unfold.** Run, pause, reset, or single-step. Change speed, zoom the board,
  and switch between the full 25 × 25 grid and its occupied region. See the robot’s complete
  movement trail, including at Turbo speed.
- **Make the board yours.** Open the sliders button above the board to choose Modern
  (default) or Classic, show/hide grid dots for counting cells, and toggle the movement
  trail. Preferences stay on this device. Resetting or editing code clears the trail;
  hiding it keeps recording.
- **Play in your language.** English, Simplified Chinese, and Japanese cover navigation,
  the guide, accessibility, and interpreter errors. Original puzzle titles/authors are preserved.
- **Use a layout that fits.** Stacked board and editor on phones; side-by-side play on iPad
  and Mac. Native text editing, cursor-aware command buttons, and `⌘ Return` on Mac.
- **Keep your progress.** Drafts, favorites, and shortest solutions save locally. Export JSON
  backups and merge them back after their solutions have been replayed and validated.
- **Keep your privacy.** No accounts, analytics SDKs, ads, or app network requests.

## Try your first program

Open problem **0001** and enter:

```text
ssss
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
| `Tests/HerbertCoreTests/` | Language unit tests and game/save/backup integration tests |
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
- Resolve original problem redistribution permissions before an App Store release.
- Add optional authenticated cloud sync while keeping offline play first.

## Credits and license

Inspired by [Herbert Online Judge](http://herbert.tealang.info/), created by **quolc**, and
its problem authors. Original [rules](http://herbert.tealang.info/rule.php) and
[problem collection](http://herbert.tealang.info/problems.php) are linked for attribution.
The original Flash client, online accounts, submissions, and leaderboard are not included;
original best scores are an import-time snapshot, not live rankings.

Our source code, original icon, and documentation use the **[MIT License](LICENSE)**.
Original third-party puzzle data and the layouts visible in screenshots are **not
relicensed under MIT**. See [NOTICE.md](NOTICE.md) for the precise scope and provenance.
