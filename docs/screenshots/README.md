# App screenshots

These PNGs are unmodified captures of the actual native SwiftUI Mac app, taken with
XCTest on October 7, 2026. Full windows are 2480 × 1700 Retina pixels. Board-only images
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
starts empty in a dedicated UI-test save file. Screenshots show the current Simplified
Chinese UI. These are Mac screenshots, not evidence of iPhone/iPad runtime validation.

Refresh with `scripts/capture_screenshots.sh` on an interactive Mac desktop. The test exports nine images and is
opt-in and skipped during ordinary UI test runs. Review the images before committing;
window size, system text rendering, and OS versions can change the output.

Original puzzle layouts retain their authors' rights and are excluded from our MIT grant.
See [NOTICE.md](../../NOTICE.md).
