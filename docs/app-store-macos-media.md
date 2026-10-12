# Herbot Bot — macOS store media

Target: `HerbertAppStore`, version 0.4.0 / build 13. Capture only the 30 original lessons. English and Simplified Chinese use separate native app launches. The Mac must be unlocked; keep other UI tests and desktop automation stopped during capture.

## Screenshots

Six actual window captures per language, with no mock interface or community content:

1. Course library: 30 original puzzles.
2. Turning rose: H editor and a recursive program.
3. Mosaic: real single-step execution.
4. Mosaic in Classic style.
5. Cathedral: the advanced course.
6. Game guide.

The window is 1440 × 900 points. On a Retina display the exported PNGs are **2880 × 1800 pixels, RGB without alpha**. The exporter rejects unexpected dimensions. Inspect every exported file before upload; fail the review if a window obscures content.

```sh
scripts/capture_app_store_media.sh en screenshots
scripts/capture_app_store_media.sh zh-Hans screenshots
```

## App Preview / promotional video

27-second narrative, using timestamped captures of the actual app window at 1600 × 900 points. Frames are sampled through XCTest, retained as attachments, and converted to a constant 30 fps video. Repeated output frames preserve the real timing of the native capture; no robot motion is synthesized.

| Time | Content |
| --- | --- |
| 0–3 s | Browse the original puzzle course |
| 3–21 s | Run the Turning rose program at the app's native 4× speed |
| 21–27 s | Step through Mosaic in Classic style |

The rose program is the existing test-only reference. It is entered through the editor and never added to app resources. The short Mosaic fragment demonstrates stepping; it is not presented as a complete solution. No AI match results, fabricated model scores, or API credentials appear. Localized captions sit in the empty middle of the sidebar; the board, code, and playback controls remain visible. There is no voiceover or music.

```sh
scripts/capture_app_store_media.sh en video
scripts/render_app_store_video.sh en-US
scripts/capture_app_store_media.sh zh-Hans video
scripts/render_app_store_video.sh zh-Hans
```

Output: `outputs/app-store-macos/0.4.0/<locale>/` (ignored by Git).

The render targets **1920 × 1080, 30 fps, progressive H.264 High Level 4.0, 10 Mbps target / 12 Mbps maximum, stereo AAC at 48 kHz**, with a silent audio track. A 5-second poster frame and `ffprobe` specification report are exported alongside the MP4. App Preview can also serve as a short promotional video. Review the complete movie before upload, including the ending and poster frame; capture and export scripts alone do not confirm finished assets.

## Uploading the delivered package

The revised English feature film and separately narrated 30-second cut are documented in [herbot-bot-promo.md](herbot-bot-promo.md). Use the newer 30-second English cut if choosing the feature-focused version with Kokoro narration and music; the original silent localized cuts remain available.

- Use `en-US` for the English listing and `zh-Hans` for Simplified Chinese.
- Upload the six numbered PNGs from each language's `screenshots/` folder. Suggested order: **02-code**, **01-library**, **05-advanced**, **03-step**, **04-classic**, **06-guide**.
- Upload `video/herbot-bot-mac-preview.mp4` in the Mac App Preview slot for the same localization. Its captions and native UI both match that language.
- `review/contact-sheet.jpg` is an overview for choosing images. It is not an upload screenshot. `video/preview-poster.jpg` is a reference for selecting the 5-second poster frame inside App Store Connect.
- The package also includes the listing text, this guide, and a manifest with file hashes and format details. Raw frame sequences and Xcode results remain local and are excluded from the delivery ZIP.

Captured and checked on 2026-10-12: both screenshot captures and both video captures passed on native macOS; all 12 numbered PNGs are RGB at 2880 × 1800; both final MP4s are 1920 × 1080 H.264 at 30 fps and approximately 27 seconds. Full video decoding and representative-frame visual checks completed successfully. No Apple upload or submission was performed.

## Apple references

- [Mac screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- [App Preview content and editing guidance](https://developer.apple.com/app-store/app-previews/)
