# App screenshots

The current README PNGs are unmodified captures of the actual native SwiftUI Mac app, taken with
XCTest on October 9, 2026. Community windows are 2480 × 1700 Retina pixels; course windows are 2480 × 2160 so the lesson and entire board fit. Board-only images
come directly from the `game-board` accessibility element's screenshot, not a separate
renderer, mockup, or image generator.

| Image | Original problem | Author | Byte limit |
| --- | --- | --- | --- |
| `library.png` | Problem library | Various; credited in app | — |
| `flower.png`, `flower-board.png`, `flower-classic.png`, `flower-classic-board.png` | 0037 · Flower | nai | 20 |
| `shuriken.png`, `shuriken-board.png` | 0027 · Shuriken | snuke | 39 |
| `butterfly.png`, `butterfly-board.png` | 0361 · Butterfly | nadsuki | 27 |

The corrected community screenshots show `*` as circular traps, not solid walls.
The Flower editor shows a valid starter program; it is not presented as a solution.
The Classic capture follows four instructions (on the open path), with a blue
trail for successful movement. Modern remains the default. Progress
starts empty in a dedicated UI-test save file. The root PNGs show Simplified Chinese
(October 9); `en/` contains the same nine captures with English UI (October 9), used by
the English README. Original problem titles and author names are preserved.
These are Mac screenshots, not evidence of iPhone/iPad runtime validation.

`en/community-reference.png` and `en/community-board-guide.png` were captured on
October 9 by `testCommunityReferenceLengthMissingRecordAndLocalizedHelp`. The first
shows #0027 Shuriken with its independent 39-byte limit and archived 14-byte Best;
the second captures the complete native popover explaining targets, walls and traps.
The popover is captured directly because it can extend beyond the main window.
Both are unmodified English app images; no model responses or personal progress are used.
The reference lengths come from the October 7 collection snapshot, not a live leaderboard.

Refresh on an interactive Mac desktop:

```sh
scripts/capture_screenshots.sh en       # English README; also the default
scripts/capture_screenshots.sh zh-Hans  # Chinese README
scripts/capture_screenshots.sh en store # Original-only English course
scripts/capture_screenshots.sh zh-Hans store # Original-only Chinese course
```

The test explicitly sets and checks the app language. It exports nine images per community run and fifteen per store run,
is opt-in, and is skipped during ordinary UI test runs. Review the images before committing;
window size, system text rendering, and OS versions can change the output.
If XCTest reports an image creation error on a secondary display, the optional
`TEST_RUNNER_HERBERT_TEST_DISPLAY="Display Name"` environment variable moves the test
window using its native Window menu. Use the destination name as shown in that menu.
For example, prefix the capture command with this variable. No monitor name is stored
in the project.

Original puzzle layouts retain their authors' rights and are excluded from our MIT grant.
See [NOTICE.md](../../NOTICE.md).

The `store` capture uses `HerbertAppStore` and exports fifteen actual native Mac images into
`en/course/` or `course/`: the 30-original library, redesigned L07 Turning rose and L08 Tandem lanterns, and L18 Hinged rosette, L24 Snowmelt seal,
L29 Vaulted mosaic, L30 Astral cathedral (full screens and boards), plus L29 in Classic
style with a three-step blue trail. The selection favors silhouettes, symmetry and
legibility; see the [design study](../advanced-course-design.md). Adjacent walls form
continuous contours. Earlier L19/L29/L30 captures remain as historical illustrations.
These independently designed original layouts and their captures use MIT.
They are not iPhone/iPad App Store screenshots.

## Herbert Benchmark

`en/battlefield/` contains actual English Mac windows captured by `BattlefieldUITests`:
provider configuration, discovered models, compact match setup, rendered Markdown rules,
a completed match with ranked model headers and two-line answers, native answer feedback,
an answer prefilled for board trial with Back to match, and the PNG sharing preview. The entrants are **deterministic fixtures**, not paid
models. They deliberately return an invalid program before retrying. The current progress,
answer and three-model history captures use L01; the separate benchmark gallery uses
L01/L02/L03, where Model 1 solves all three and Model 2 earns partial or zero points on later puzzles. Thus
the test verifies parallel requests, retry feedback, native judging, ranking, answer trials/back navigation
and history. Current captures use unified Match Settings without time or token limits,
allowing all fixture entrants to finish.
These images illustrate the application and do not benchmark a commercial model.
No real API key or personal provider configuration appears in these captures.

`herbert-benchmark-user-run.png` is a user-supplied English app capture, replaced on
October 9 with the twelve-community-puzzle run showing four model columns. It includes
stopped and failed answers and illustrates a partial run, without establishing a
controlled commercial-model ranking.

`ai-share.png` was refreshed from the app's actual PNG export during the passing
`testParallelMatchRetryNativeJudgingHistoryAndShareImage` case in
`.build/benchmark-metrics-ui.xcresult`. Both deterministic entrants have two attempts,
1,800 input / 24 output tokens and a provider-reported total of 2,400 tokens. The first
fixture reports a 50% cache rate; the second omits cache data, so its card hides that
metric. The image includes cumulative model time, points and match duration and remains
an unmodified English app export.

On October 9, `ai-battlefield.png`, `ai-answer.png`, `ai-history.png` and
`ai-thinking.png` were refreshed from `.build/attempt-timing-ui.xcresult` to show total
points beside normalized percentages and each attempt's elapsed timer. Fixture replies
take less than one second and display `00:00:00`; the streaming reasoning fixture
shows a live eight-second attempt. All four images are unmodified English app captures.

Later on October 9, `ai-history.png` was replaced with the full-page History view from
`.build/full-history-final-ui.xcresult`. The test expands the main window to 1,420 × 910
points, verifies three model columns and the persistent **Back to match history** action,
and separately checks that answer dialogs still resize. The image is an unmodified
English app capture with three deterministic entrants solving L01.

The compact-workspace refresh on October 9 updates the match headers, contextual
progress help and title tags in `ai-history.png`, `ai-battlefield.png` and `ai-trial.png`.
The history/progress captures use the native fixture suites, with two or three entrants
solving L01. The history replacement comes from the passing history case in
`.build/compact-workspaces-final-confirmation.xcresult`. The progress and trial replacements come from the passing
`testParallelMatchRetryNativeJudgingHistoryAndShareImage` case in
`.build/compact-workspaces-capture-ui.xcresult`, with popover disappearance checked
before capture. `en/compact-playground.png` comes from
`.build/compact-workspaces-popup-final.xcresult`: an actual 932 × 430-point Mac window
showing all four sidebar destinations, the complete board and code editor, and Run on
entry. It validates shared short-height SwiftUI layout and is not an iPhone screenshot.
All replacement images remain unmodified English app captures.

On an interactive Mac desktop, capture the fixture flow with:

```sh
TEST_RUNNER_HERBERT_CAPTURE_SCREENSHOTS=1 xcodebuild \
  -project Herbert.xcodeproj -scheme Herbert -destination 'platform=macOS' \
  -derivedDataPath .build/battlefield-screenshots \
  -resultBundlePath .build/battlefield-screenshots.xcresult CODE_SIGN_IDENTITY=- \
  -only-testing:HerbertUITests/BattlefieldUITests test
xcrun xcresulttool export attachments \
  --path .build/battlefield-screenshots.xcresult \
  --output-path .build/battlefield-screenshots-attachments
```

Use the manifest's `readme-ai-*` attachment names to select the PNGs, then inspect
language, counts and window visibility before copying them into the gallery. The
optional display environment variable described above works for these tests too.
The share preview comes from the app's ImageRenderer and PNG export flow.

0.3.2 adds `ai-reasoning.png` and `ai-provider-error.png`, captured from isolated deterministic
responses while the answer dialog updates. The HTTP 400 message is a fixture illustrating
diagnostics, not a captured Kimi API response. The three-puzzle gallery uses L01/L02/L03.

0.3.3 adds English captures of the persistent 64K output editor and resizable three-model history. Model reasoning is independently collapsed by default and expanded in its Markdown capture. The diagnostic fixture declares a 4,096-token provider limit to demonstrate exhaustion despite the new configurable 64K default.
