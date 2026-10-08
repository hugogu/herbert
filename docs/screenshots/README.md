# App screenshots

These PNGs are unmodified captures of the actual native SwiftUI Mac app, taken with
XCTest on October 7–8, 2026. Community windows are 2480 × 1700 Retina pixels; course windows are 2480 × 2160 so the lesson and entire board fit. Board-only images
come directly from the `game-board` accessibility element's screenshot, not a separate
renderer, mockup, or image generator.

| Image | Original problem | Author | Byte limit |
| --- | --- | --- | --- |
| `library.png` | Problem library | Various; credited in app | — |
| `flower.png`, `flower-board.png`, `flower-classic.png`, `flower-classic-board.png` | 0037 · Flower | nai | 20 |
| `shuriken.png`, `shuriken-board.png` | 0027 · Shuriken | snuke | 39 |
| `butterfly.png`, `butterfly-board.png` | 0361 · Butterfly | nadsuki | 27 |

The Flower editor shows a valid starter program; it is not presented as a solution.
The Classic capture follows four instructions (including blocked moves), with a blue
trail for successful movement. Modern remains the default. Progress
starts empty in a dedicated UI-test save file. The root PNGs show Simplified Chinese
(October 7); `en/` contains the same nine captures with English UI (October 8), used by
the English README. Original problem titles and author names are preserved.
These are Mac screenshots, not evidence of iPhone/iPad runtime validation.

Refresh on an interactive Mac desktop:

```sh
scripts/capture_screenshots.sh en       # English README; also the default
scripts/capture_screenshots.sh zh-Hans  # Chinese README
scripts/capture_screenshots.sh en store # Original-only English course
scripts/capture_screenshots.sh zh-Hans store # Original-only Chinese course
```

The test explicitly sets and checks the app language. It exports nine images per run,
is opt-in, and is skipped during ordinary UI test runs. Review the images before committing;
window size, system text rendering, and OS versions can change the output.
If XCTest reports an image creation error on a secondary display, the optional
`TEST_RUNNER_HERBERT_TEST_DISPLAY="Display Name"` environment variable moves the test
window using its native Window menu. Use the destination name as shown in that menu.
For example, prefix the capture command with this variable. No monitor name is stored
in the project.

Original puzzle layouts retain their authors' rights and are excluded from our MIT grant.
See [NOTICE.md](../../NOTICE.md).

The `store` capture uses `HerbertAppStore` and exports seven actual native Mac images into
`en/course/` or `course/`: the original-only library and L19 Growing spiral, L29 Nested
windows, L30 Clockwork garden (full screens and boards). These independently designed
original layouts and their captures use MIT. They are not iPhone/iPad App Store screenshots.
